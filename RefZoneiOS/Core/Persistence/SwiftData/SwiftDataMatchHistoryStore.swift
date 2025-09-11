//
//  SwiftDataMatchHistoryStore.swift
//  RefWatchiOS
//
//  iOS implementation of MatchHistoryStoring backed by SwiftData.
//
//  Responsibilities
//  - Persist completed match snapshots using a SwiftData model (`CompletedMatchRecord`).
//  - On first use, perform a one-time import from the legacy JSON store with de-duplication by `id`.
//  - Attach `ownerId` using the injected `AuthenticationProviding` if the snapshot is missing it (idempotent).
//  - Post `.matchHistoryDidChange` notifications on the main thread after mutations.
//
//  Threading & Actor
//  - The store is `@MainActor` to align with SwiftData usage in this app and simplify UI integration.
//  - Encoding/decoding JSON blobs happen synchronously on the main actor; payload sizes are limited to single snapshots.
//
//  Loading Strategy
//  - `loadAll()` returns a bounded, most-recent-first list (default limit applied) to avoid unbounded memory use.
//  - A `loadPage(offset:limit:)` helper is provided for full-history screens.
//

import Foundation
import SwiftData
import RefWatchCore

@MainActor
final class SwiftDataMatchHistoryStore: MatchHistoryStoring {
    private let container: ModelContainer
    private let context: ModelContext
    private let auth: AuthenticationProviding
    private let importFlagKey = "rw_history_imported_v1"

    init(container: ModelContainer, auth: AuthenticationProviding = NoopAuth(), importJSONOnFirstRun: Bool = true) {
        self.container = container
        self.context = ModelContext(container)
        self.auth = auth
        if importJSONOnFirstRun {
            importFromLegacyJSONIfNeeded()
        }
    }

    // MARK: - MatchHistoryStoring
    /// Loads a bounded set of most recent completed matches.
    ///
    /// Note: This method intentionally applies a default fetch limit to avoid
    /// unbounded memory use when many rows exist. Use `loadPage(offset:limit:)`
    /// when full pagination is needed.
    func loadAll() throws -> [CompletedMatch] {
        var desc = FetchDescriptor<CompletedMatchRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        // Reasonable default bound to protect memory on large datasets
        desc.fetchLimit = 200
        let rows = try context.fetch(desc)
        return rows.compactMap { Self.decode($0.payload) }
    }

    /// Paginates completed matches using SwiftData’s fetch offset/limit.
    func loadPage(offset: Int, limit: Int) throws -> [CompletedMatch] {
        var desc = FetchDescriptor<CompletedMatchRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        desc.fetchOffset = max(0, offset)
        desc.fetchLimit = max(1, limit)
        let rows = try context.fetch(desc)
        return rows.compactMap { Self.decode($0.payload) }
    }

    /// Cursor-based pagination that returns snapshots completed strictly before the given timestamp.
    /// When `completedAt` is `nil`, returns the newest `limit` snapshots.
    func loadBefore(completedAt: Date?, limit: Int) throws -> [CompletedMatch] {
        var desc = FetchDescriptor<CompletedMatchRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        desc.fetchLimit = max(1, limit)
        if let cutoff = completedAt {
            desc.predicate = #Predicate { $0.completedAt < cutoff }
        }
        let rows = try context.fetch(desc)
        return rows.compactMap { Self.decode($0.payload) }
    }

    func save(_ match: CompletedMatch) throws {
        let snapshot = attachOwnerIfNeeded(match)
        let data = try Self.encode(snapshot)

        if let existing = try fetchRecord(id: snapshot.id) {
            existing.completedAt = snapshot.completedAt
            existing.ownerId = snapshot.ownerId
            existing.homeTeam = snapshot.match.homeTeam
            existing.awayTeam = snapshot.match.awayTeam
            existing.homeScore = snapshot.match.homeScore
            existing.awayScore = snapshot.match.awayScore
            existing.payload = data
        } else {
            let row = CompletedMatchRecord(
                id: snapshot.id,
                completedAt: snapshot.completedAt,
                ownerId: snapshot.ownerId,
                homeTeam: snapshot.match.homeTeam,
                awayTeam: snapshot.match.awayTeam,
                homeScore: snapshot.match.homeScore,
                awayScore: snapshot.match.awayScore,
                payload: data
            )
            context.insert(row)
        }
        try context.save()
        NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
    }

    func delete(id: UUID) throws {
        if let existing = try fetchRecord(id: id) {
            context.delete(existing)
            try context.save()
            NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
        }
    }

    func wipeAll() throws {
        var desc = FetchDescriptor<CompletedMatchRecord>()
        let all = try context.fetch(desc)
        for item in all { context.delete(item) }
        try context.save()
        NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
    }

    // MARK: - Import
    /// Performs a best-effort, one-time import from the legacy JSON store.
    ///
    /// Steps:
    /// - Check a `UserDefaults` flag to skip work if already imported.
    /// - Load existing SwiftData rows and build a Set of IDs to avoid duplicates.
    /// - Load all legacy JSON snapshots; for each item not in the ID set, upsert via `save(_:)`.
    /// - Mark the flag as imported even if partial failures occur (best-effort policy).
    ///
    /// Rationale:
    /// - Keeps first-run cost predictable and resilient to partial data inconsistencies.
    /// - Uses `save(_:)` path to centralize owner attachment and notifications.
    private func importFromLegacyJSONIfNeeded() {
        if UserDefaults.standard.bool(forKey: importFlagKey) { return }
        let legacy = MatchHistoryService() // JSON-based
        let items = (try? legacy.loadAll()) ?? []
        guard !items.isEmpty else {
            UserDefaults.standard.set(true, forKey: importFlagKey)
            return
        }
        // Build an index of existing IDs to avoid duplicates if partial import occurred
        let existingIds = Set((try? context.fetch(FetchDescriptor<CompletedMatchRecord>()))?.map { $0.id } ?? [])
        for item in items where !existingIds.contains(item.id) {
            do { try save(item) } catch { /* continue best-effort */ }
        }
        UserDefaults.standard.set(true, forKey: importFlagKey)
    }

    // MARK: - Helpers
    private func fetchRecord(id: UUID) throws -> CompletedMatchRecord? {
        var desc = FetchDescriptor<CompletedMatchRecord>(predicate: #Predicate { $0.id == id })
        desc.fetchLimit = 1
        return try context.fetch(desc).first
    }

    /// Attaches the current user as owner if snapshot lacks an `ownerId`.
    private func attachOwnerIfNeeded(_ match: CompletedMatch) -> CompletedMatch {
        match.attachingOwnerIfMissing(using: auth)
    }

    private static func encoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }

    private static func decoder() -> JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }

    private static func encode(_ obj: CompletedMatch) throws -> Data { try encoder().encode(obj) }
    private static func decode(_ data: Data) -> CompletedMatch? { try? decoder().decode(CompletedMatch.self, from: data) }
}
