import Foundation
import RefWorkoutCore

enum WorkoutFeatureBootstrap {
  static func makeSampleSession() -> WorkoutSession {
    WorkoutSession(
      kind: .strength,
      title: "Gym Circuit",
      startedAt: Date(),
      segments: [
        WorkoutSegment(name: "Warmup", purpose: .warmup, plannedDuration: 300),
        WorkoutSegment(name: "Circuit", purpose: .work, plannedDuration: 1500),
        WorkoutSegment(name: "Cooldown", purpose: .cooldown, plannedDuration: 300)
      ],
      metrics: [WorkoutMetric(kind: .duration, value: 2100, unit: .seconds)],
      intensityProfile: [.aerobic, .tempo]
    )
  }
}
