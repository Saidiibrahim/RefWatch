import Foundation

public protocol WorkoutSessionTracking: Sendable {
  func startSession(configuration: WorkoutSessionConfiguration) async throws -> WorkoutSession
  func pauseSession(id: UUID) async throws
  func resumeSession(id: UUID) async throws
  func endSession(id: UUID, at date: Date) async throws -> WorkoutSession
  func recordEvent(_ event: WorkoutEvent, sessionId: UUID) async
}
