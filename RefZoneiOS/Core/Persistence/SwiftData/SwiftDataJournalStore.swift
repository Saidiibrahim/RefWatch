//
//  SwiftDataJournalStore.swift
//  RefZoneiOS
//
//  iOS implementation of JournalEntryStoring backed by SwiftData.
//

import Foundation
import SwiftData
import RefWatchCore

extension Notification.Name {
    static let journalDidChange = Notification.Name("JournalDidChange")
}

@MainActor
final class SwiftDataJournalStore: JournalEntryStoring {
    private let container: ModelContainer
    private let context: ModelContext
    private let auth: AuthenticationProviding

    init(container: ModelContainer, auth: AuthenticationProviding) {
        self.container = container
        self.context = ModelContext(container)
        self.auth = auth
    }

    // MARK: - Load
    func loadEntries(for matchId: UUID) throws -> [JournalEntry] {
        var desc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.matchId == matchId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        desc.fetchLimit = 500
        return try context.fetch(desc).map(Self.map)
    }

    func loadLatest(for matchId: UUID) throws -> JournalEntry? {
        var desc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate { $0.matchId == matchId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        desc.fetchLimit = 1
        return try context.fetch(desc).first.map(Self.map)
    }

    func loadRecent(limit: Int) throws -> [JournalEntry] {
        var desc = FetchDescriptor<JournalEntryRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        desc.fetchLimit = max(1, limit)
        return try context.fetch(desc).map(Self.map)
    }

    // MARK: - Mutations
    func upsert(_ entry: JournalEntry) throws {
        if let existing = try fetchRecord(id: entry.id) {
            existing.updatedAt = entry.updatedAt
            existing.ownerId = entry.ownerId ?? existing.ownerId
            existing.rating = entry.rating
            existing.overall = entry.overall
            existing.wentWell = entry.wentWell
            existing.toImprove = entry.toImprove
        } else {
            let owned = attachOwnerIfNeeded(entry)
            let row = JournalEntryRecord(
                id: owned.id,
                matchId: owned.matchId,
                createdAt: owned.createdAt,
                updatedAt: owned.updatedAt,
                ownerId: owned.ownerId,
                rating: owned.rating,
                overall: owned.overall,
                wentWell: owned.wentWell,
                toImprove: owned.toImprove
            )
            context.insert(row)
        }
        try context.save()
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }

    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) throws -> JournalEntry {
        var entry = JournalEntry(
            matchId: matchId,
            ownerId: nil,
            rating: rating,
            overall: overall,
            wentWell: wentWell,
            toImprove: toImprove
        )
        entry = attachOwnerIfNeeded(entry)
        try upsert(entry)
        return entry
    }

    func delete(id: UUID) throws {
        if let record = try fetchRecord(id: id) {
            context.delete(record)
            try context.save()
            NotificationCenter.default.post(name: .journalDidChange, object: nil)
        }
    }

    func deleteAll(for matchId: UUID) throws {
        let all = try context.fetch(FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.matchId == matchId }))
        for r in all { context.delete(r) }
        try context.save()
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }

    // MARK: - Helpers
    private func fetchRecord(id: UUID) throws -> JournalEntryRecord? {
        var desc = FetchDescriptor<JournalEntryRecord>(predicate: #Predicate { $0.id == id })
        desc.fetchLimit = 1
        return try context.fetch(desc).first
    }

    private func attachOwnerIfNeeded(_ entry: JournalEntry) -> JournalEntry {
        guard entry.ownerId == nil, let uid = auth.currentUserId else { return entry }
        var e = entry
        e.ownerId = uid
        return e
    }

    private static func map(_ r: JournalEntryRecord) -> JournalEntry {
        JournalEntry(
            id: r.id,
            matchId: r.matchId,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            ownerId: r.ownerId,
            rating: r.rating,
            overall: r.overall,
            wentWell: r.wentWell,
            toImprove: r.toImprove
        )
    }
}
