// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZylixSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ZylixSwift",
            targets: ["ZylixSwift"]
        ),
    ],
    dependencies: [],
    targets: [
        // C library target wrapping the Zig static library
        .target(
            name: "CZylix",
            dependencies: [],
            path: "Sources/CZylix",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                // Link to the Zig-compiled static library
                // The library path will be provided by the consuming project
                .linkedLibrary("zylix")
            ]
        ),

        // Swift wrapper target
        .target(
            name: "ZylixSwift",
            dependencies: ["CZylix"],
            path: "Sources/ZylixSwift"
        ),

        // Tests
        .testTarget(
            name: "ZylixSwiftTests",
            dependencies: ["ZylixSwift"],
            path: "Tests/ZylixSwiftTests"
        ),
    ]
)
