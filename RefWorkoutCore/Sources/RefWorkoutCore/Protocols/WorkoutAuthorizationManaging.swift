import Foundation

public protocol WorkoutAuthorizationManaging: Sendable {
  func authorizationStatus() async -> WorkoutAuthorizationStatus
  func requestAuthorization() async throws -> WorkoutAuthorizationStatus
}
