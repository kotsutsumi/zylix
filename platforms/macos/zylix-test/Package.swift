// swift-tools-version:5.9
// Zylix Test Framework - macOS Accessibility Bridge

import PackageDescription

let package = Package(
    name: "ZylixTest",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ZylixTest",
            targets: ["ZylixTest"]
        ),
        .executable(
            name: "zylix-test-server",
            targets: ["ZylixTestServer"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZylixTest",
            dependencies: [],
            path: "Sources/ZylixTest"
        ),
        .executableTarget(
            name: "ZylixTestServer",
            dependencies: ["ZylixTest"],
            path: "Sources/ZylixTestServer"
        ),
    ]
)
