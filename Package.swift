// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AIUsageMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AIUsageMonitor", targets: ["AIUsageMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "AIUsageMonitor",
            path: "Sources/AIUsageMonitor"
        ),
        .testTarget(
            name: "AIUsageMonitorTests",
            dependencies: ["AIUsageMonitor"],
            path: "Tests/AIUsageMonitorTests"
        )
    ]
)
