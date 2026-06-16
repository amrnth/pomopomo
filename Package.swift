// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
        .library(name: "PomodoroKit", targets: ["PomodoroKit"]),
    ],
    targets: [
        .target(
            name: "PomodoroKit",
            path: "Sources/PomodoroKit"
        ),
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroKit"],
            path: "Sources/Pomodoro"
        ),
        .testTarget(
            name: "PomodoroTests",
            dependencies: ["PomodoroKit"],
            path: "Tests/PomodoroTests"
        ),
    ]
)
