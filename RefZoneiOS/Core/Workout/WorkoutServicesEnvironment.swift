import SwiftUI
import RefWorkoutCore

private struct WorkoutServicesKey: EnvironmentKey {
  static let defaultValue: WorkoutServices = .inMemoryStub()
}

public extension EnvironmentValues {
  var workoutServices: WorkoutServices {
    get { self[WorkoutServicesKey.self] }
    set { self[WorkoutServicesKey.self] = newValue }
  }
}

public extension View {
  func workoutServices(_ services: WorkoutServices) -> some View {
    environment(\.workoutServices, services)
  }
}
