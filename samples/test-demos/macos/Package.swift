// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSTestDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacOSTestDemo",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "MacOSTestDemoTests",
            dependencies: ["MacOSTestDemo"],
            path: "Tests"
        )
    ]
)
