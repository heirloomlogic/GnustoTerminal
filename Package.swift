// swift-tools-version: 6.2
import Foundation
import PackageDescription

// Forward the development server trait through the complete dependency graph.
let forwarded: Set<Package.Dependency.Trait> = [
    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))
]
// This override develops against the current engine checkout, including edits.
let engineDependency: Package.Dependency =
    ProcessInfo.processInfo.environment["GNUSTO_ENGINE_PATH"].map {
        .package(name: "Gnusto", path: $0, traits: forwarded)
    }
    ?? .package(
        url: "https://github.com/HeirloomLogic/Gnusto",
        branch: "main",
        traits: forwarded)

let package = Package(
    name: "GnustoTerminal",
    platforms: [.macOS(.v15)],
    products: [.library(name: "GnustoTerminal", targets: ["GnustoTerminal"])],
    traits: [
        .trait(name: "Playtest", description: "Enable Gnusto MCP launch."),
        .default(enabledTraits: ["Playtest"]),
    ],
    dependencies: [engineDependency],
    targets: [
        .target(
            name: "GnustoTerminal",
            dependencies: [.product(name: "Gnusto", package: "Gnusto")]),
        .testTarget(
            name: "GnustoTerminalTests",
            dependencies: ["GnustoTerminal"]),
    ]
)
