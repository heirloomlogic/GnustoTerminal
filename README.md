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

Long openings begin at the top with a `-- more (PgDn) --` marker. Mouse wheel gestures scroll the transcript; PageUp/PageDown move by a page, and Up/Down recall commands. Typing, pasting, editing or recalling a command returns to the live prompt. Ctrl-C and Escape cancel save/restore filename prompts. At a command prompt Ctrl-C asks before quitting, and Escape cancels that confirmation.

Tab extends a word as far as every matching candidate agrees, adding a trailing space only when the match is unique. Ambiguous words with no shared extension stay unchanged, and no suggestions are added to the game transcript. For example, `s` stays `s`, `so` becomes `south` without a space, and `southe` becomes `southeast `.

`GNUSTO_SEED` pins the engine's random stream. `GNUSTO_STATUS`, `GNUSTO_TRANSCRIPT`, `GNUSTO_TRANSCRIPT_DIR` and `GNUSTO_SAVE_DIR` retain Gnusto's existing behavior. The launcher's environment argument selects mode, seed, status and transcript behavior; save-directory resolution continues to use the engine's process environment policy.

`--mcp` or `GNUSTO_MCP` selects the play-test server before terminal construction. The `Playtest` trait is enabled by default and forwarded to Gnusto. Deployment builds must disable default traits across the complete dependency graph. The engine reports unavailable MCP support on standard error; protocol output belongs only on standard output.

## Developing with a local engine checkout

```sh
GNUSTO_ENGINE_PATH=/absolute/path/to/Gnusto swift test
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests Package.swift
```

The development override uses the current engine checkout, including uncommitted edits. Generated build packages must resolve their game and terminal dependencies against that same engine identity. The manifest's default `main` branch dependency is a prerelease integration reference, not an immutable release pin; replace it with the coordinated published version during release handoff.

The Swift suite exercises launcher policy, key decoding, paste folding, completion, word boundaries, status-bar widths and history persistence without taking over a live terminal. `python3 Tests/terminal-pty.py /absolute/path/to/built/Zork1/launcher` checks opening position, scrolling, history, editing, prompt cancellation and exact terminal-attribute restoration through a real PTY. Native mouse gestures and visual presentation still need a terminal acceptance check.

## CI and documentation

CI checks out a reviewed Gnusto integration revision and supplies `GNUSTO_ENGINE_PATH`; it does not imply that the packages are released or compatible with their respective default branches. Linux uses Swift 6.3.3 with the same backend and prebuilt policy as Gnusto. macOS tests run on the macOS 26 runner. The dependency-graph check runs without maintainer tooling and rejects DocC or Persnicket in the library graph.

The checked-in `.swift-format` configuration supports strict lint without attaching a build-tool plugin to the library. Documentation uses its own maintainer sentinel:

```sh
touch .dev-tooling
GNUSTO_ENGINE_PATH=/absolute/path/to/Gnusto swift package --manifest-cache none resolve
GNUSTO_ENGINE_PATH=/absolute/path/to/Gnusto swift package --manifest-cache none --allow-writing-to-directory .docs-build generate-documentation --target GnustoTerminal --output-path .docs-build --warnings-as-errors
```

Remove `.dev-tooling` and use `--manifest-cache none` when checking the published dependency graph. Ordinary consumers resolve only the engine dependency; the command-only DocC plugin is available solely in a maintainer checkout with the sentinel present. Generated build packages retain ordinary resolved dependency pins in their ignored `Package.resolved` files. The generated workspace binds the remote frontend as a managed SwiftPM edit so it can use the selected current engine. SwiftPM omits edited dependencies from `Package.resolved`; the frontend's original branch and exact revision remain in `scratch/workspace-state.json` under the dependency's `basedOn` state. The generated mode directory also records the frontend URL, branch, revision, checkout path and source fingerprint in `terminal-source.json` and successful `build-state.json` metadata. These paths are under the author package's `.build-launchers/<Game>/<development|deployment>/` directory. Release acceptance replaces branch requirements with compatible immutable versions and builds a fresh author package against those versions.
