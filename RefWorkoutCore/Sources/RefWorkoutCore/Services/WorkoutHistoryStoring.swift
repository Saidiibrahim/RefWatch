import Foundation

public protocol WorkoutHistoryStoring: Sendable {
  func loadSessions(limit: Int?) async throws -> [WorkoutSession]
  func saveSession(_ session: WorkoutSession) async throws
  func deleteSession(id: UUID) async throws
  func wipeAll() async throws
}
