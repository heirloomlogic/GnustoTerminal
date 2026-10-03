# GnustoTerminal

GnustoTerminal is the standard terminal front end for [Gnusto](https://github.com/HeirloomLogic/Gnusto). It supports macOS 15 and Linux and provides a reusable library; executable entry points belong to generated game build packages.

A launcher imports a game library exporting `PackagedGame` and returns the launch status to the operating system:

```swift
import GnustoTerminal
import MyGame

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main struct Launcher {
    static func main() async {
        let status = await TerminalLaunch.run(MyGame.game)
        exit(status)
    }
}
```

`TerminalLaunch.run` returns zero after a normal session and one when bootstrap fails or MCP is unavailable.

Both standard input and standard output must be a TTY for the full-screen display. Piped or redirected sessions use plain IO. `GNUSTO_PLAIN`, with any value including an empty string, forces plain IO. Interactive sessions preserve the status bar, line editing, bracketed paste, persistent command history and completion. The engine owns shared width calculations, text wrapping, REPL behavior, saves and transcripts.

`GNUSTO_SEED` pins the engine's random stream. `GNUSTO_STATUS`, `GNUSTO_TRANSCRIPT`, `GNUSTO_TRANSCRIPT_DIR` and `GNUSTO_SAVE_DIR` retain Gnusto's existing behavior. The launcher's environment argument selects mode, seed, status and transcript behavior; save-directory resolution continues to use the engine's process environment policy.

`--mcp` or `GNUSTO_MCP` selects the play-test server before terminal construction. The `Playtest` trait is enabled by default and forwarded to Gnusto. Deployment builds must disable default traits across the complete dependency graph. The engine reports unavailable MCP support on standard error; protocol output belongs only on standard output.

## Developing with a local engine checkout

```sh
GNUSTO_ENGINE_PATH=/absolute/path/to/Gnusto swift test
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests Package.swift
```

The development override uses the current engine checkout, including uncommitted edits. Generated build packages must resolve their game and terminal dependencies against that same engine identity. The manifest's default `main` branch dependency is a prerelease integration reference, not an immutable release pin; replace it with the coordinated published version during release handoff.

The suite exercises launcher policy, key decoding, paste folding, completion, word boundaries, status-bar widths and history persistence without taking over a live terminal. Raw-mode restoration, resize rendering and Ctrl-C confirmation still require live terminal acceptance.
