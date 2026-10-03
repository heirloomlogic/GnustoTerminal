import Foundation
import Gnusto

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Composes a packaged game with Gnusto's standard terminal front end.
public enum TerminalLaunch {
    /// Runs the MCP server or a terminal session without terminating the process.
    ///
    /// Startup diagnostics are written before the interactive handler changes the
    /// screen. MCP selection happens before bootstrap and terminal construction.
    /// The generated executable is responsible for passing the returned status to
    /// the operating system.
    ///
    /// - Parameters:
    ///   - game: The factory supplying a fresh game for each world.
    ///   - arguments: Process arguments, including the executable path first.
    ///   - environment: Mode, seed, status and transcript settings. Save-directory
    ///     resolution retains the engine's process-environment policy.
    /// - Returns: Zero after normal completion, or one after bootstrap failure or
    ///   an unavailable MCP request.
    public static func run(
        _ game: PackagedGame,
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async -> Int32 {
        if PlaytestMode.requested(arguments: arguments, environment: environment) {
            do {
                try await PlaytestLaunch.serve(game, environment: environment)
                return 0
            } catch {
                writeToStandardError(String(describing: error))
                return 1
            }
        }
        do {
            let seed = SeedRequest(environment: environment)
            let status = StatusFooter(environment: environment)
            let prepared = try PreparedGame(game.makeGame())
            // Randomness remains the engine's policy, not a launcher policy.
            let world =
                seed.value.map { GameWorld(prepared: prepared, seed: $0) }
                ?? GameWorld(prepared: prepared)
            let transcript = TranscriptRequest(gameTitled: prepared.title, environment: environment)
            for message in [
                seed.complaint, status.complaint,
                transcript.complaint, prepared.warningReport,
            ].compactMap({ $0 }) {
                writeToStandardError(message)
            }
            let interactive = usesInteractiveIO(
                arguments: arguments, environment: environment,
                stdinIsTTY: isatty(STDIN_FILENO) == 1,
                stdoutIsTTY: isatty(STDOUT_FILENO) == 1)
            let io: any IOHandler =
                interactive
                ? TerminalIOHandler(historyURL: await world.historyFileURL)
                : ConsoleIOHandler()
            await REPL(
                world: world, io: io,
                transcriptURL: transcript.url, status: status.inForce,
                environment: environment
            ).run()
            return 0
        } catch {
            writeToStandardError(String(describing: error))
            return 1
        }
    }

    /// Interactive presentation requires both streams to be terminals and no
    /// GNUSTO_PLAIN flag. Arguments do not influence this already-selected path.
    static func usesInteractiveIO(
        arguments: [String], environment: [String: String],
        stdinIsTTY: Bool, stdoutIsTTY: Bool
    ) -> Bool {
        stdinIsTTY && stdoutIsTTY && environment["GNUSTO_PLAIN"] == nil
    }
}
