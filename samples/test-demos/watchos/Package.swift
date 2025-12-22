// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchOSTestDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WatchOSTestDemo",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "WatchOSTestDemoTests",
            dependencies: ["WatchOSTestDemo"],
            path: "Tests"
        )
    ]
)
