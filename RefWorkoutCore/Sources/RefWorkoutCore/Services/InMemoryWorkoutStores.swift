import Foundation

public actor InMemoryWorkoutHistoryStore: WorkoutHistoryStoring {
  private var sessionsById: [UUID: WorkoutSession]

  public init(initialSessions: [WorkoutSession] = []) {
    self.sessionsById = Dictionary(uniqueKeysWithValues: initialSessions.map { ($0.id, $0) })
  }

  public func loadSessions(limit: Int?) async throws -> [WorkoutSession] {
    let sorted = sessionsById.values.sorted { lhs, rhs in
      lhs.startedAt > rhs.startedAt
    }
    guard let limit else { return sorted }
    return Array(sorted.prefix(limit))
  }

  public func saveSession(_ session: WorkoutSession) async throws {
    sessionsById[session.id] = session
  }

  public func deleteSession(id: UUID) async throws {
    sessionsById.removeValue(forKey: id)
  }

  public func wipeAll() async throws {
    sessionsById.removeAll()
  }
}

public actor InMemoryWorkoutPresetStore: WorkoutPresetStoring {
  private var presetsById: [UUID: WorkoutPreset]

  public init(initialPresets: [WorkoutPreset] = []) {
    self.presetsById = Dictionary(uniqueKeysWithValues: initialPresets.map { ($0.id, $0) })
  }

  public func loadPresets() async throws -> [WorkoutPreset] {
    presetsById.values.sorted { lhs, rhs in
      lhs.createdAt > rhs.createdAt
    }
  }

  public func savePreset(_ preset: WorkoutPreset) async throws {
    presetsById[preset.id] = preset.withUpdatedTimestamp()
  }

  public func deletePreset(id: UUID) async throws {
    presetsById.removeValue(forKey: id)
  }
}

private extension WorkoutPreset {
  func withUpdatedTimestamp() -> WorkoutPreset {
    var copy = self
    copy.updatedAt = Date()
    return copy
  }
}
