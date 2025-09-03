// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RefWatchCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RefWatchCore", targets: ["RefWatchCore"]),
    ],
    dependencies: [
        // No external dependencies; uses Foundation and Observation
    ],
    targets: [
        .target(
            name: "RefWatchCore",
            path: "Sources/RefWatchCore"
        ),
        .testTarget(
            name: "RefWatchCoreTests",
            dependencies: ["RefWatchCore"],
            path: "Tests/RefWatchCoreTests"
        ),
    ]
)
