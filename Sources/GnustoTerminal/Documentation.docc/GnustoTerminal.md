# ``GnustoTerminal``

Launch a packaged Gnusto game in a terminal on macOS 15 or Linux.

## Overview

GnustoTerminal supplies the terminal front end as a reusable library. A game library exports a `Gnusto.PackagedGame` value, and an ignored generated build package supplies its executable entry point. Neither Gnusto nor the game library depends on GnustoTerminal.

The launcher calls ``TerminalLaunch/run(_:arguments:environment:)`` and passes the returned status to `exit`. Normal completion returns zero. Fatal bootstrap diagnostics or an unavailable play-test server return one and write their explanation to standard error.

```swift
import GnustoTerminal
import MyGame

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

let status = await TerminalLaunch.run(MyGame.game)
exit(status)
```

Both standard input and standard output must be a terminal for interactive rendering. Piped or redirected sessions use plain input and output. Setting `GNUSTO_PLAIN` to any value, including an empty string, forces plain input and output. Interactive sessions retain status rendering, line editing, bracketed paste, command completion and persistent history. Gnusto owns shared display-width calculations, text wrapping, the REPL, save handling and transcripts.

`GNUSTO_SEED` selects a reproducible random stream. `GNUSTO_STATUS`, `GNUSTO_TRANSCRIPT` and `GNUSTO_TRANSCRIPT_DIR` preserve the engine's existing session policies. Save-directory resolution uses Gnusto's process environment, including `GNUSTO_SAVE_DIR`.

`--mcp` or `GNUSTO_MCP` selects the play-test server before constructing terminal input and output. The package's default `Playtest` trait forwards to Gnusto. Generated deployment packages disable the trait throughout the dependency graph and use a separate build cache; their executable refuses MCP mode on standard error. MCP standard output is reserved for protocol messages.

## Development and deployment

Use Gnusto's `bin/run-game`, `bin/export-game`, `bin/gnusto-mcp`, replay and preflight tools. These tools generate a launcher for one catalog game and ensure the game and front end resolve the same engine module. Exported games include any required adjacent resource bundles and run without Node or a Swift toolchain.

`GNUSTO_ENGINE_PATH` points this package's development manifest at a local engine checkout, including uncommitted edits. The default `main` dependency is a prerelease integration reference. Coordinated immutable package versions and a fresh author-package build remain release acceptance requirements.

## Topics

### Launching a game

- ``TerminalLaunch``
- ``TerminalLaunch/run(_:arguments:environment:)``
