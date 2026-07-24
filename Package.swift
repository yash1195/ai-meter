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
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.4"
        )
    ],
    targets: [
        .executableTarget(
            name: "AIUsageMonitor",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/AIUsageMonitor",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "AIUsageMonitorTests",
            dependencies: ["AIUsageMonitor"],
            path: "Tests/AIUsageMonitorTests",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
