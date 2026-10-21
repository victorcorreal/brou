// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Brou",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Brou",
            path: "Sources/Brou",
            // Same reasoning as the canvas app next door: the whole interface is
            // main-thread by nature, and Swift 6's strict isolation buys nothing
            // here but ceremony.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "BrouTests",
            dependencies: ["Brou"],
            path: "Tests/BrouTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
