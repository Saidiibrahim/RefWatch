import Foundation

public protocol WorkoutPresetStoring: Sendable {
  func loadPresets() async throws -> [WorkoutPreset]
  func savePreset(_ preset: WorkoutPreset) async throws
  func deletePreset(id: UUID) async throws
}
