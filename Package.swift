// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DocTwin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DocTwin", targets: ["DocTwin"])
    ],
    targets: [
        .target(name: "DocTwinCore"),
        .executableTarget(
            name: "DocTwin",
            dependencies: ["DocTwinCore"]
        ),
        .testTarget(
            name: "DocTwinCoreTests",
            dependencies: ["DocTwinCore"]
        )
    ]
)
