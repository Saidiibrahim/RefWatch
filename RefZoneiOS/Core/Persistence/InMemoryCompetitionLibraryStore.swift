//
//  InMemoryCompetitionLibraryStore.swift
//  RefZoneiOS
//
//  In-memory implementation of CompetitionLibraryStoring for testing and previews.
//

import Foundation
import Combine

/// In-memory implementation of competition storage for testing
final class InMemoryCompetitionLibraryStore: CompetitionLibraryStoring {
    private var competitions: [CompetitionRecord] = []
    private let changesSubject = PassthroughSubject<[CompetitionRecord], Never>()

    var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
        changesSubject.eraseToAnyPublisher()
    }

    init(preloadedCompetitions: [CompetitionRecord] = []) {
        self.competitions = preloadedCompetitions
    }

    func loadAll() throws -> [CompetitionRecord] {
        competitions.sorted { $0.name < $1.name }
    }

    func search(query: String) throws -> [CompetitionRecord] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try loadAll()
        }

        let lowercased = query.lowercased()
        return competitions
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
            needsRemoteSync: true
        )

        competitions.append(record)
        notifyChanges()

        return record
    }

    func update(_ competition: CompetitionRecord) throws {
        guard let index = competitions.firstIndex(where: { $0.id == competition.id }) else {
            throw NSError(domain: "InMemoryStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Competition not found"])
        }

        competition.lastModifiedAt = Date()
        competition.needsRemoteSync = true
        competitions[index] = competition

        notifyChanges()
    }

    func delete(_ competition: CompetitionRecord) throws {
        competitions.removeAll { $0.id == competition.id }
        notifyChanges()
    }

    func wipeAllForLogout() throws {
        competitions.removeAll()
        notifyChanges()
    }

    // MARK: - Helpers

    private func notifyChanges() {
        let sorted = competitions.sorted { $0.name < $1.name }
        changesSubject.send(sorted)
    }
}