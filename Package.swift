// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomopomo",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Pomopomo", targets: ["Pomopomo"]),
        .library(name: "PomopomoKit", targets: ["PomopomoKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "PomopomoKit",
            path: "Sources/PomopomoKit"
        ),
        .executableTarget(
            name: "Pomopomo",
            dependencies: [
                "PomopomoKit",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/Pomopomo"
        ),
        .testTarget(
            name: "PomopomoTests",
            dependencies: ["PomopomoKit"],
            path: "Tests/PomopomoTests"
        ),
    ]
)
