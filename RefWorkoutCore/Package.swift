// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RefWorkoutCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RefWorkoutCore", targets: ["RefWorkoutCore"]),
    ],
    dependencies: [
        // No external dependencies yet; HealthKit/WorkoutKit remain platform-side adapters
    ],
    targets: [
        .target(
            name: "RefWorkoutCore",
            path: "Sources/RefWorkoutCore"
        ),
        .testTarget(
            name: "RefWorkoutCoreTests",
            dependencies: ["RefWorkoutCore"],
            path: "Tests/RefWorkoutCoreTests"
        ),
    ]
)
