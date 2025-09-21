import Foundation
import RefWorkoutCore

struct WorkoutModeBootstrap {
  static let samplePreset = WorkoutPreset(
    title: "Tempo Intervals",
    kind: .outdoorRun,
    segments: [
      WorkoutSegment(name: "Warmup", purpose: .warmup, plannedDuration: 600),
      WorkoutSegment(
        name: "Intervals",
        purpose: .work,
        plannedDuration: 1200,
        plannedDistance: 3000,
        target: WorkoutSegment.Target(
          metric: .averagePace,
          value: 4.5,
          unit: .minutesPerKilometer,
          intensityZone: .tempo
        )
      ),
      WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 420)
    ]
  )
}
