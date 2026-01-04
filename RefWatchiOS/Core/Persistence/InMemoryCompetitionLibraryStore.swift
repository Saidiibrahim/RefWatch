//
//  InMemoryCompetitionLibraryStore.swift
//  RefWatchiOS
//
//  In-memory implementation of CompetitionLibraryStoring for testing and previews.
//

import Combine
import Foundation

/// In-memory implementation of competition storage for testing
final class InMemoryCompetitionLibraryStore: CompetitionLibraryStoring {
  private var competitions: [CompetitionRecord] = []
  private let changesSubject = PassthroughSubject<[CompetitionRecord], Never>()

  var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
    self.changesSubject.eraseToAnyPublisher()
  }

  init(preloadedCompetitions: [CompetitionRecord] = []) {
    self.competitions = preloadedCompetitions
  }

  func loadAll() throws -> [CompetitionRecord] {
    self.competitions.sorted { $0.name < $1.name }
  }

  func search(query: String) throws -> [CompetitionRecord] {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return try self.loadAll()
    }

    let lowercased = query.lowercased()
    return self.competitions
      .filter { $0.name.lowercased().contains(lowercased) }
      .sorted { $0.name < $1.name }
  }

  func create(name: String, level: String?) throws -> CompetitionRecord {
    let record = CompetitionRecord(
      id: UUID(),
      name: name,
      level: level,
      ownerSupabaseId: "test-user",
      lastModifiedAt: Date(),
      remoteUpdatedAt: nil,
      needsRemoteSync: true)

    self.competitions.append(record)
    self.notifyChanges()

    return record
  }

  func update(_ competition: CompetitionRecord) throws {
    guard let index = competitions.firstIndex(where: { $0.id == competition.id }) else {
      throw NSError(
        domain: "InMemoryStore",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Competition not found"])
    }

    competition.lastModifiedAt = Date()
    competition.needsRemoteSync = true
    self.competitions[index] = competition

    self.notifyChanges()
  }

  func delete(_ competition: CompetitionRecord) throws {
    self.competitions.removeAll { $0.id == competition.id }
    self.notifyChanges()
  }

  func wipeAllForLogout() throws {
    self.competitions.removeAll()
    self.notifyChanges()
  }

  func refreshFromRemote() async throws {
    // No-op for in-memory store used in previews/tests
  }

  // MARK: - Helpers

  private func notifyChanges() {
    let sorted = self.competitions.sorted { $0.name < $1.name }
    self.changesSubject.send(sorted)
  }
}
