//
//  JournalStoring.swift
//  RefWatchCore
//
//  Storage protocol for self-assessment journal entries.
//

import Foundation

@MainActor
public protocol JournalEntryStoring {
    func loadEntries(for matchId: UUID) async throws -> [JournalEntry]
    func loadLatest(for matchId: UUID) async throws -> JournalEntry?
    func loadRecent(limit: Int) async throws -> [JournalEntry]

    func upsert(_ entry: JournalEntry) async throws
    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) async throws -> JournalEntry

    func delete(id: UUID) async throws
    func deleteAll(for matchId: UUID) async throws
    func wipeAllForLogout() async throws
}

public extension JournalEntryStoring {
    func loadRecent() async -> [JournalEntry] {
        (try? await loadRecent(limit: 50)) ?? []
    }
}
