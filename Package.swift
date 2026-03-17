// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RockyCLI",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "RockyCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                "RockyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            plugins: [
                .plugin(name: "VersionPlugin"),
            ]
        ),
        .testTarget(
            name: "RockyCoreTests",
            dependencies: ["RockyCore"]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"]
        ),
        .executableTarget(
            name: "VersionGen"
        ),
        .plugin(
            name: "VersionPlugin",
            capability: .buildTool(),
            dependencies: ["VersionGen"]
        ),
    ]
)
