import Testing

@testable import GnustoTerminal

struct TerminalLaunchTests {
    @Test(arguments: [
        (true, true, false, true),
        (true, false, false, false),
        (false, true, false, false),
        (false, false, false, false),
        (true, true, true, false),
    ])
    func interactivePolicy(stdin: Bool, stdout: Bool, forced: Bool, expected: Bool) {
        let environment = forced ? ["GNUSTO_PLAIN": ""] : [:]
        #expect(
            TerminalLaunch.usesInteractiveIO(
                arguments: ["game"], environment: environment,
                stdinIsTTY: stdin, stdoutIsTTY: stdout) == expected)
    }

    @Test(arguments: ["0", "false", "plain"])
    func everyPlainFlagValueDisablesInteractiveIO(_ value: String) {
        #expect(
            !TerminalLaunch.usesInteractiveIO(
                arguments: ["game"], environment: ["GNUSTO_PLAIN": value],
                stdinIsTTY: true, stdoutIsTTY: true))
    }

    @Test func ordinaryArgumentsDoNotChangeInteractiveSelection() {
        #expect(
            TerminalLaunch.usesInteractiveIO(
                arguments: ["game", "--plain", "look"], environment: [:],
                stdinIsTTY: true, stdoutIsTTY: true))
    }

    @Test(arguments: ["", "0", "false"])
    func everyMCPFlagValueRequestsServer(_ value: String) {
        #expect(PlaytestMode.requested(arguments: ["game"], environment: ["GNUSTO_MCP": value]))
    }

    @Test func mcpArgumentSelectsServer() {
        #expect(PlaytestMode.requested(arguments: ["game", "--mcp"], environment: [:]))
    }

    @Test func executableNameIsNotAnMCPArgument() {
        #expect(!PlaytestMode.requested(arguments: ["--mcp"], environment: [:]))
        #expect(!PlaytestMode.requested(arguments: [], environment: [:]))
        #expect(!PlaytestMode.requested(arguments: ["game", "--mcp-extra"], environment: [:]))
    }
}
