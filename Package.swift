// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "simdeck",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SimDeck", targets: ["SimDeck"])
    ],
    targets: [
        .executableTarget(
            name: "SimDeck",
            path: "Sources/SimDeck"
        ),
        .testTarget(
            name: "SimDeckTests",
            dependencies: ["SimDeck"],
            path: "Tests/SimDeckTests"
        )
    ]
)
