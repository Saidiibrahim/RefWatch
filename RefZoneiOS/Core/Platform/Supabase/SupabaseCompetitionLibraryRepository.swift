//
//  SupabaseCompetitionLibraryRepository.swift
//  RefZoneiOS
//
//  Wraps the SwiftData competition store with Supabase sync behavior. Local changes
//  remain immediately available while the repository coordinates background
//  pushes and periodic pulls using the Supabase API.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SupabaseCompetitionLibraryRepository: CompetitionLibraryStoring {
    private let store: SwiftDataCompetitionLibraryStore
    private let api: SupabaseCompetitionLibraryServing
    private let authStateProvider: SupabaseAuthStateProviding
    private let backlog: CompetitionLibrarySyncBacklogStoring
    private let log = AppLog.supabase
    private let dateProvider: () -> Date

    private var authCancellable: AnyCancellable?
    private var ownerUUID: UUID?
    private var pendingPushes: Set<UUID> = []
    private var pendingDeletions: Set<UUID>
    private var processingTask: Task<Void, Never>?
    private var remoteCursor: Date?

    var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
        store.changesPublisher
    }

    init(
        store: SwiftDataCompetitionLibraryStore,
        authStateProvider: SupabaseAuthStateProviding,
        api: SupabaseCompetitionLibraryServing = SupabaseCompetitionLibraryAPI(),
        backlog: CompetitionLibrarySyncBacklogStoring = SupabaseCompetitionSyncBacklogStore(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.authStateProvider = authStateProvider
        self.api = api
        self.backlog = backlog
        self.dateProvider = dateProvider
        self.pendingDeletions = backlog.loadPendingDeletionIDs()
        publishSyncStatus()

        if let userId = authStateProvider.currentUserId,
           let uuid = UUID(uuidString: userId) {
            ownerUUID = uuid
        }

        authCancellable = authStateProvider.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    await self?.handleAuthState(state)
                }
            }

        if ownerUUID != nil {
            scheduleInitialSync()
        }
    }

    deinit {
        authCancellable?.cancel()
        processingTask?.cancel()
    }

    // MARK: - CompetitionLibraryStoring

    func loadAll() throws -> [CompetitionRecord] {
        try store.loadAll()
    }

    func search(query: String) throws -> [CompetitionRecord] {
        try store.search(query: query)
    }

    func create(name: String, level: String?) throws -> CompetitionRecord {
        let record = try store.create(name: name, level: level)
        applyOwnerIdentityIfNeeded(to: record)
        enqueuePush(for: record.id)
        return record
    }

    func update(_ competition: CompetitionRecord) throws {
        try store.update(competition)
        applyOwnerIdentityIfNeeded(to: competition)
        enqueuePush(for: competition.id)
    }

    func delete(_ competition: CompetitionRecord) throws {
        let competitionId = competition.id
        try store.delete(competition)
        pendingPushes.remove(competitionId)
        pendingDeletions.insert(competitionId)
        backlog.addPendingDeletion(id: competitionId)
        scheduleProcessingTask()
        publishSyncStatus()
    }

    func wipeAllForLogout() throws {
        try store.wipeAllForLogout()
    }
}

// MARK: - Identity Handling & Sync Scheduling

private extension SupabaseCompetitionLibraryRepository {
    func handleAuthState(_ state: AuthState) async {
        switch state {
        case .signedOut:
            ownerUUID = nil
            remoteCursor = nil
            processingTask?.cancel()
            processingTask = nil
            pendingPushes.removeAll()
            pendingDeletions.removeAll()
            backlog.clearAll()
            do {
                try store.wipeAllForLogout()
                log.notice("Cleared local competition library after sign-out")
            } catch {
                log.error("Failed to wipe competitions on sign-out: \(error.localizedDescription, privacy: .public)")
            }
            publishSyncStatus()

        case let .signedIn(userId, _, _):
            guard let uuid = UUID(uuidString: userId) else {
                log.error("Competition sync received non-UUID Supabase id: \(userId, privacy: .public)")
                return
            }
            ownerUUID = uuid
            publishSyncStatus()
            scheduleInitialSync()
        }
    }

    func scheduleInitialSync() {
        scheduleProcessingTask()
        Task { [weak self] in
            await self?.performInitialSync()
        }
    }

    func performInitialSync() async {
        guard let ownerUUID else { return }
        do {
            try await flushPendingDeletions()
            try await pushDirtyCompetitions()
            try await pullRemoteUpdates(for: ownerUUID)
        } catch {
            log.error("Initial competition sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Queue Processing

private extension SupabaseCompetitionLibraryRepository {
    enum SyncOperation {
        case push(UUID)
        case delete(UUID)
    }

    func enqueuePush(for competitionId: UUID) {
        pendingPushes.insert(competitionId)
        applyOwnerIdentityIfNeeded(competitionId: competitionId)
        scheduleProcessingTask()
        publishSyncStatus()
    }

    func scheduleProcessingTask() {
        guard processingTask == nil else { return }
        processingTask = Task { [weak self] in
            guard let self else { return }
            await self.drainQueues()
            await MainActor.run { self.processingTask = nil }
        }
    }

    func drainQueues() async {
        while !Task.isCancelled {
            guard let operation = await nextOperation() else { break }
            switch operation {
            case .delete(let id):
                await performRemoteDeletion(id: id)
            case .push(let id):
                await performRemotePush(id: id)
            }
        }
    }

    func nextOperation() async -> SyncOperation? {
        await MainActor.run {
            if let deletion = pendingDeletions.popFirst() {
                return .delete(deletion)
            }
            guard ownerUUID != nil else { return nil }
            if let push = pendingPushes.popFirst() {
                return .push(push)
            }
            return nil
        }
    }
}

// MARK: - Remote Operations

private extension SupabaseCompetitionLibraryRepository {
    func flushPendingDeletions() async throws {
        while let deletionId = pendingDeletions.popFirst() {
            await performRemoteDeletion(id: deletionId)
            try await Task.sleep(nanoseconds: 10_000_000) // Small delay between operations
        }
    }

    func performRemoteDeletion(id: UUID) async {
        do {
            try await api.deleteCompetition(competitionId: id)
            backlog.removePendingDeletion(id: id)
        } catch {
            pendingDeletions.insert(id)
            log.error("Supabase competition delete failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second backoff
        }
        publishSyncStatus()
    }

    func pushDirtyCompetitions() async throws {
        guard ownerUUID != nil else { return }
        let records = try store.loadAll().filter { $0.needsRemoteSync }
        guard !records.isEmpty else { return }

        for record in records {
            pendingPushes.insert(record.id)
            applyOwnerIdentityIfNeeded(to: record)
        }
        scheduleProcessingTask()
        publishSyncStatus()
    }

    func performRemotePush(id: UUID) async {
        guard let ownerUUID else {
            pendingPushes.insert(id)
            return
        }

        guard let records = try? store.loadAll(),
              let record = records.first(where: { $0.id == id }) else {
            // Record no longer exists locally, skip push
            return
        }

        let request = SupabaseCompetitionLibraryAPI.CompetitionRequest(
            id: record.id,
            ownerId: ownerUUID,
            name: record.name,
            level: record.level
        )

        do {
            let result = try await api.syncCompetition(request)
            record.needsRemoteSync = false
            record.remoteUpdatedAt = result.updatedAt
            record.lastModifiedAt = dateProvider()
            record.ownerSupabaseId = ownerUUID.uuidString
            try store.context.save()

            remoteCursor = max(remoteCursor ?? result.updatedAt, result.updatedAt)
        } catch {
            pendingPushes.insert(id)
            log.error("Supabase competition push failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
        publishSyncStatus()
    }

    func pullRemoteUpdates(for ownerUUID: UUID) async throws {
        let remoteCompetitions = try await api.fetchCompetitions(ownerId: ownerUUID, updatedAfter: remoteCursor)
        guard !remoteCompetitions.isEmpty else { return }

        var didChange = false
        for remote in remoteCompetitions {
            if pendingDeletions.contains(remote.id) {
                continue
            }

            let existingRecords = try store.loadAll()
            if let existing = existingRecords.first(where: { $0.id == remote.id }) {
                // Update existing record if remote is newer
                let localDirty = existing.needsRemoteSync
                let localRemoteDate = existing.remoteUpdatedAt ?? .distantPast

                if localDirty && remote.updatedAt <= localRemoteDate {
                    // Local changes take precedence
                    continue
                }

                existing.name = remote.name
                existing.level = remote.level
                existing.ownerSupabaseId = remote.ownerId.uuidString
                existing.remoteUpdatedAt = remote.updatedAt
                existing.lastModifiedAt = dateProvider()
                existing.needsRemoteSync = false
                didChange = true
            } else {
                // Insert new record
                let newRecord = CompetitionRecord(
                    id: remote.id,
                    name: remote.name,
                    level: remote.level,
                    ownerSupabaseId: remote.ownerId.uuidString,
                    lastModifiedAt: dateProvider(),
                    remoteUpdatedAt: remote.updatedAt,
                    needsRemoteSync: false
                )
                store.context.insert(newRecord)
                didChange = true
            }
        }

        if didChange {
            try store.context.save()
        }

        if let maxDate = remoteCompetitions.map({ $0.updatedAt }).max() {
            remoteCursor = max(remoteCursor ?? maxDate, maxDate)
        }
        publishSyncStatus()
    }
}

// MARK: - Helpers

private extension SupabaseCompetitionLibraryRepository {
    func publishSyncStatus() {
        let info: [String: Any] = [
            "component": "competition_library",
            "pendingPushes": pendingPushes.count,
            "pendingDeletions": pendingDeletions.count,
            "signedIn": ownerUUID != nil,
            "timestamp": dateProvider()
        ]
        NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
    }

    func applyOwnerIdentityIfNeeded(to record: CompetitionRecord) {
        guard let ownerUUID else { return }
        if record.ownerSupabaseId != ownerUUID.uuidString {
            record.ownerSupabaseId = ownerUUID.uuidString
            try? store.context.save()
        }
    }

    func applyOwnerIdentityIfNeeded(competitionId: UUID) {
        guard let ownerUUID else { return }
        guard let records = try? store.loadAll(),
              let record = records.first(where: { $0.id == competitionId }) else {
            return
        }
        applyOwnerIdentityIfNeeded(to: record)
    }
}
