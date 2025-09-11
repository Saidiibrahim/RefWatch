//
//  JournalStoring.swift
//  RefWatchCore
//
//  Storage protocol for self-assessment journal entries.
//

import Foundation

@MainActor
public protocol JournalEntryStoring {
    func loadEntries(for matchId: UUID) throws -> [JournalEntry]
    func loadLatest(for matchId: UUID) throws -> JournalEntry?
    func loadRecent(limit: Int) throws -> [JournalEntry]

    func upsert(_ entry: JournalEntry) throws
    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) throws -> JournalEntry

    func delete(id: UUID) throws
    func deleteAll(for matchId: UUID) throws
}

public extension JournalEntryStoring {
    func loadRecent() -> [JournalEntry] {
        (try? loadRecent(limit: 50)) ?? []
    }
}

