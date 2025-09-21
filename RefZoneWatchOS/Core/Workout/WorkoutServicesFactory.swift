import Foundation
import HealthKit
import RefWorkoutCore

@MainActor
enum WorkoutServicesFactory {
  static func makeDefault() -> WorkoutServices {
    guard HKHealthStore.isHealthDataAvailable() else {
      return WorkoutServices.inMemoryStub(presets: [WorkoutModeBootstrap.samplePreset])
    }

    let healthStore = HKHealthStore()
    let authorization = HealthKitWorkoutAuthorizationManager(healthStore: healthStore)
    let tracker = HealthKitWorkoutTracker(healthStore: healthStore)
    let history = InMemoryWorkoutHistoryStore()
    let presets = InMemoryWorkoutPresetStore(initialPresets: [WorkoutModeBootstrap.samplePreset])

    return WorkoutServices(
      authorizationManager: authorization,
      sessionTracker: tracker,
      historyStore: history,
      presetStore: presets
    )
  }
}
