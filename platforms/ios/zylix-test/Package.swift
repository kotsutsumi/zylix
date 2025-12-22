// swift-tools-version:5.9
// Zylix Test Framework - iOS XCUITest Bridge

import PackageDescription

let package = Package(
    name: "ZylixTest",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ZylixTest",
            targets: ["ZylixTest"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ZylixTest",
            dependencies: [],
            path: "Sources/ZylixTest"
        ),
        .testTarget(
            name: "ZylixTestTests",
            dependencies: ["ZylixTest"],
            path: "Tests/ZylixTestTests"
        ),
    ]
)
