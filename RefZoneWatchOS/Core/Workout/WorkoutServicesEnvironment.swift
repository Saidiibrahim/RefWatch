import SwiftUI
import RefWorkoutCore

private struct WorkoutServicesKey: EnvironmentKey {
  @MainActor
  static var defaultValue: WorkoutServices { .inMemoryStub() }
}

@MainActor
public extension EnvironmentValues {
  var workoutServices: WorkoutServices {
    get { self[WorkoutServicesKey.self] }
    set { self[WorkoutServicesKey.self] = newValue }
  }
}

@MainActor
public extension View {
  func workoutServices(_ services: WorkoutServices) -> some View {
    environment(\.workoutServices, services)
  }
}
