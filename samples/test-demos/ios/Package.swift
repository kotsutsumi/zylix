// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IOSTestDemo",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "IOSTestDemo",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "IOSTestDemoTests",
            dependencies: ["IOSTestDemo"],
            path: "Tests"
        )
    ]
)
