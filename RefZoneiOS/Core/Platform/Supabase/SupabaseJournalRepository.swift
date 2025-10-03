//
//  SupabaseJournalRepository.swift
//  RefZoneiOS
//
//  Supabase-backed implementation of JournalEntryStoring that keeps an
//  in-memory cache and always uses the cloud as the source of truth.
//

import Combine
import Foundation
import OSLog
import RefWatchCore

@MainActor
final class SupabaseJournalRepository: JournalEntryStoring {
    private let api: SupabaseJournalServing
    private let authStateProvider: SupabaseAuthStateProviding
    private let dateProvider: () -> Date
    private let log = AppLog.supabase

    private var authCancellable: AnyCancellable?
    private var ownerUUID: UUID?
    private var pullTask: Task<Void, Never>?

    private var entriesByMatch: [UUID: [JournalEntry]] = [:]

    init(
        authStateProvider: SupabaseAuthStateProviding,
        api: SupabaseJournalServing = SupabaseJournalAPI(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.api = api
        self.authStateProvider = authStateProvider
        self.dateProvider = dateProvider

        if let userId = authStateProvider.currentUserId,
           let uuid = UUID(uuidString: userId) {
            ownerUUID = uuid
            triggerPull()
        }

        authCancellable = authStateProvider.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    await self?.handleAuthState(state)
                }
            }
    }

    deinit {
        authCancellable?.cancel()
        pullTask?.cancel()
    }

    // MARK: - JournalEntryStoring

    func loadEntries(for matchId: UUID) async throws -> [JournalEntry] {
        if entriesByMatch[matchId] == nil {
            triggerPull(force: true)
        } else {
            triggerPull()
        }
        return entriesByMatch[matchId] ?? []
    }

    func loadLatest(for matchId: UUID) async throws -> JournalEntry? {
        try await loadEntries(for: matchId).first
    }

    func loadRecent(limit: Int) async throws -> [JournalEntry] {
        triggerPull()
        let all = entriesByMatch.values.flatMap { $0 }
        return Array(all.sorted(by: { $0.updatedAt > $1.updatedAt })
            .prefix(max(1, limit)))
    }

    func upsert(_ entry: JournalEntry) async throws {
        let owner = try requireOwnerUUID(operation: "save journal entry")
        let now = dateProvider()
        var requestEntry = entry
        requestEntry.ownerId = owner.uuidString
        requestEntry.updatedAt = now

        let request = SupabaseJournalAPI.AssessmentRequest(
            id: requestEntry.id,
            matchId: requestEntry.matchId,
            ownerId: owner,
            rating: requestEntry.rating,
            overall: requestEntry.overall,
            wentWell: requestEntry.wentWell,
            toImprove: requestEntry.toImprove,
            createdAt: requestEntry.createdAt,
            updatedAt: now
        )

        let result = try await api.syncAssessment(request)

        requestEntry.updatedAt = result.updatedAt
        cache(entry: requestEntry)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
    }

    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) async throws -> JournalEntry {
        let owner = try requireOwnerUUID(operation: "create journal entry")
        let now = dateProvider()
        var entry = JournalEntry(
            matchId: matchId,
            createdAt: now,
            updatedAt: now,
            ownerId: owner.uuidString,
            rating: rating,
            overall: overall,
            wentWell: wentWell,
            toImprove: toImprove
        )

        let request = SupabaseJournalAPI.AssessmentRequest(
            id: entry.id,
            matchId: entry.matchId,
            ownerId: owner,
            rating: entry.rating,
            overall: entry.overall,
            wentWell: entry.wentWell,
            toImprove: entry.toImprove,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )

        let result = try await api.syncAssessment(request)

        entry.updatedAt = result.updatedAt
        cache(entry: entry)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
        return entry
    }

    func delete(id: UUID) async throws {
        _ = try requireOwnerUUID(operation: "delete journal entry")
        try await api.deleteAssessment(id: id)
        removeEntry(withId: id)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
    }

    func deleteAll(for matchId: UUID) async throws {
        let entries = entriesByMatch[matchId] ?? []
        for entry in entries {
            try await delete(id: entry.id)
        }
    }

    func wipeAllForLogout() async throws {
        entriesByMatch.removeAll()
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }
}

// MARK: - Auth Handling

private extension SupabaseJournalRepository {
    func handleAuthState(_ state: AuthState) async {
        switch state {
        case .signedOut:
            ownerUUID = nil
            pullTask?.cancel()
            pullTask = nil
            entriesByMatch.removeAll()
            NotificationCenter.default.post(name: .journalDidChange, object: nil)
        case let .signedIn(userId, _, _):
            guard let uuid = UUID(uuidString: userId) else {
                log.error("Journal sync received non-UUID Supabase id: \(userId, privacy: .public)")
                return
            }
            ownerUUID = uuid
            triggerPull(force: true)
        }
    }
}

// MARK: - Remote Fetching

private extension SupabaseJournalRepository {
    func triggerPull(force: Bool = false) {
        guard ownerUUID != nil else { return }
        if !force, pullTask != nil { return }
        pullTask?.cancel()
        pullTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.pullAllEntries()
            } catch {
                self.log.error("Journal pull failed: \(error.localizedDescription, privacy: .public)")
            }
            await MainActor.run { self.pullTask = nil }
        }
    }

    func pullAllEntries() async throws {
        guard let ownerUUID else { return }
        let remoteEntries = try await api.fetchAssessments(ownerId: ownerUUID, updatedAfter: nil)
        let journalEntries = remoteEntries.map { remote -> JournalEntry in
            JournalEntry(
                id: remote.id,
                matchId: remote.matchId,
                createdAt: remote.createdAt,
                updatedAt: remote.updatedAt,
                ownerId: remote.ownerId.uuidString,
                rating: remote.rating,
                overall: remote.overall,
                wentWell: remote.wentWell,
                toImprove: remote.toImprove
            )
        }
        applyRemoteSnapshot(journalEntries)
    }
}

// MARK: - Cache Management

private extension SupabaseJournalRepository {
    func cache(entry: JournalEntry) {
        var list = entriesByMatch[entry.matchId] ?? []
        if let idx = list.firstIndex(where: { $0.id == entry.id }) {
            list[idx] = entry
        } else {
            list.append(entry)
        }
        list.sort { $0.updatedAt > $1.updatedAt }
        entriesByMatch[entry.matchId] = list
    }

    func removeEntry(withId id: UUID) {
        for (matchId, var list) in entriesByMatch {
            let newList = list.filter { $0.id != id }
            if newList.count != list.count {
                if newList.isEmpty {
                    entriesByMatch.removeValue(forKey: matchId)
                } else {
                    entriesByMatch[matchId] = newList
                }
                break
            }
        }
    }

    func applyRemoteSnapshot(_ entries: [JournalEntry]) {
        var grouped: [UUID: [JournalEntry]] = [:]
        for entry in entries {
            grouped[entry.matchId, default: []].append(entry)
        }
        for (key, value) in grouped {
            grouped[key] = value.sorted { $0.updatedAt > $1.updatedAt }
        }
        entriesByMatch = grouped
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }
}

// MARK: - Helpers

private extension SupabaseJournalRepository {
    func requireOwnerUUID(operation: String) throws -> UUID {
        guard let userId = authStateProvider.currentUserId,
              let uuid = UUID(uuidString: userId) else {
            throw PersistenceAuthError.signedOut(operation: operation)
        }
        return uuid
    }
}
