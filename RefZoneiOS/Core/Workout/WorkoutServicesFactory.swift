import Foundation
import HealthKit
import RefWorkoutCore

@MainActor
enum IOSWorkoutServicesFactory {
  static func makeDefault() -> WorkoutServices {
    guard HKHealthStore.isHealthDataAvailable() else {
      return WorkoutServices.inMemoryStub()
    }

    guard #available(iOS 17.0, *) else {
      return WorkoutServices.inMemoryStub()
    }

    let healthStore = HKHealthStore()
    let authorization = IOSHealthKitWorkoutAuthorizationManager(healthStore: healthStore)
    let tracker = IOSHealthKitWorkoutTracker(healthStore: healthStore)
    let history = InMemoryWorkoutHistoryStore()
    let presets = InMemoryWorkoutPresetStore()

    return WorkoutServices(
      authorizationManager: authorization,
      sessionTracker: tracker,
      historyStore: history,
      presetStore: presets
    )
  }
}
