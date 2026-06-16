// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomopomo",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Pomopomo", targets: ["Pomopomo"]),
        .library(name: "PomopomoKit", targets: ["PomopomoKit"]),
    ],
    targets: [
        .target(
            name: "PomopomoKit",
            path: "Sources/PomopomoKit"
        ),
        .executableTarget(
            name: "Pomopomo",
            dependencies: ["PomopomoKit"],
            path: "Sources/Pomopomo"
        ),
        .testTarget(
            name: "PomopomoTests",
            dependencies: ["PomopomoKit"],
            path: "Tests/PomopomoTests"
        ),
    ]
)
