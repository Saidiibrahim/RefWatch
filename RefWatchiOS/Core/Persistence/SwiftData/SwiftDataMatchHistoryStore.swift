//
//  SwiftDataMatchHistoryStore.swift
//  RefWatchiOS
//
//  iOS implementation of MatchHistoryStoring backed by SwiftData.
//  Performs a one-time import from the legacy JSON store on first use.
//

import Foundation
import SwiftData
import RefWatchCore

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
    func loadAll() throws -> [CompletedMatch] {
        var desc = FetchDescriptor<CompletedMatchRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        desc.fetchLimit = 0
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

    private func attachOwnerIfNeeded(_ match: CompletedMatch) -> CompletedMatch {
        guard match.ownerId == nil, let uid = auth.currentUserId else { return match }
        return CompletedMatch(
            id: match.id,
            completedAt: match.completedAt,
            match: match.match,
            events: match.events,
            schemaVersion: match.schemaVersion,
            ownerId: uid
        )
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
