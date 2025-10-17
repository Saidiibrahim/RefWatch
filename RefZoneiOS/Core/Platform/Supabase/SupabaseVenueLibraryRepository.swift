//
//  SupabaseVenueLibraryRepository.swift
//  RefZoneiOS
//
//  Wraps the SwiftData venue store with Supabase sync behavior. Local changes
//  remain immediately available while the repository coordinates background
//  pushes and periodic pulls using the Supabase API.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SupabaseVenueLibraryRepository: VenueLibraryStoring {
    private let store: SwiftDataVenueLibraryStore
    private let api: SupabaseVenueLibraryServing
    private let authStateProvider: SupabaseAuthStateProviding
    private let backlog: VenueLibrarySyncBacklogStoring
    private let log = AppLog.supabase
    private let dateProvider: () -> Date
    private let isoFormatter: ISO8601DateFormatter

    private var authCancellable: AnyCancellable?
    private var ownerUUID: UUID?
    private var pendingPushes: Set<UUID> = []
    private var pendingDeletions: Set<UUID>
    private var processingTask: Task<Void, Never>?
    private var remoteCursor: Date?

    var changesPublisher: AnyPublisher<[VenueRecord], Never> {
        store.changesPublisher
    }

    init(
        store: SwiftDataVenueLibraryStore,
        authStateProvider: SupabaseAuthStateProviding,
        api: SupabaseVenueLibraryServing = SupabaseVenueLibraryAPI(),
        backlog: VenueLibrarySyncBacklogStoring = SupabaseVenueSyncBacklogStore(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.authStateProvider = authStateProvider
        self.api = api
        self.backlog = backlog
        self.dateProvider = dateProvider
        self.isoFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
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

    // MARK: - VenueLibraryStoring

    func loadAll() throws -> [VenueRecord] {
        try store.loadAll()
    }

    func search(query: String) throws -> [VenueRecord] {
        try store.search(query: query)
    }

    func create(name: String, city: String?, country: String?) throws -> VenueRecord {
        let record = try store.create(name: name, city: city, country: country)
        applyOwnerIdentityIfNeeded(to: record)
        enqueuePush(for: record.id)
        return record
    }

    func update(_ venue: VenueRecord) throws {
        try store.update(venue)
        applyOwnerIdentityIfNeeded(to: venue)
        enqueuePush(for: venue.id)
    }

    func delete(_ venue: VenueRecord) throws {
        let venueId = venue.id
        try store.delete(venue)
        pendingPushes.remove(venueId)
        pendingDeletions.insert(venueId)
        backlog.addPendingDeletion(id: venueId)
        scheduleProcessingTask()
        publishSyncStatus()
    }

    func wipeAllForLogout() throws {
        try store.wipeAllForLogout()
    }

    func refreshFromRemote() async throws {
        guard let ownerUUID else {
            throw PersistenceAuthError.signedOut(operation: "refresh venues")
        }
        try await pullRemoteUpdates(for: ownerUUID)
    }
}

// MARK: - Identity Handling & Sync Scheduling

private extension SupabaseVenueLibraryRepository {
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
                log.notice("Cleared local venue library after sign-out")
            } catch {
                log.error("Failed to wipe venues on sign-out: \(error.localizedDescription, privacy: .public)")
            }
            publishSyncStatus()

        case let .signedIn(userId, _, _):
            guard let uuid = UUID(uuidString: userId) else {
                log.error("Venue sync received non-UUID Supabase id: \(userId, privacy: .public)")
                return
            }
            ownerUUID = uuid
            remoteCursor = nil
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
        let ownerString = ownerUUID.uuidString
        let startingCursor = describe(remoteCursor)

        log.notice(
            "Venue initial sync started owner=\(ownerString, privacy: .public) cursor=\(startingCursor, privacy: .public) pendingPush=\(self.pendingPushes.count) pendingDelete=\(self.pendingDeletions.count)"
        )

        do {
            if !pendingDeletions.isEmpty {
                log.debug("Venue initial sync flushing pending deletions count=\(self.pendingDeletions.count)")
            }
            try await flushPendingDeletions()

            log.debug("Venue initial sync scanning for dirty venues")
            try await pushDirtyVenues()
            log.debug("Venue initial sync queued pending pushes=\(self.pendingPushes.count)")

            log.debug("Venue initial sync pulling remote updates cursor=\(self.describe(self.remoteCursor), privacy: .public)")
            try await pullRemoteUpdates(for: ownerUUID)

            log.notice(
                "Venue initial sync finished owner=\(ownerString, privacy: .public) cursor=\(self.describe(self.remoteCursor), privacy: .public) pendingPush=\(self.pendingPushes.count) pendingDelete=\(self.pendingDeletions.count)"
            )
        } catch {
            log.error(
                "Initial venue sync failed owner=\(ownerString, privacy: .public) cursor=\(startingCursor, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: - Queue Processing

private extension SupabaseVenueLibraryRepository {
    enum SyncOperation {
        case push(UUID)
        case delete(UUID)
    }

    func enqueuePush(for venueId: UUID) {
        pendingPushes.insert(venueId)
        applyOwnerIdentityIfNeeded(venueId: venueId)
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

private extension SupabaseVenueLibraryRepository {
    func flushPendingDeletions() async throws {
        while let deletionId = pendingDeletions.popFirst() {
            await performRemoteDeletion(id: deletionId)
            try await Task.sleep(nanoseconds: 10_000_000) // Small delay between operations
        }
    }

    func performRemoteDeletion(id: UUID) async {
        do {
            try await api.deleteVenue(venueId: id)
            backlog.removePendingDeletion(id: id)
        } catch {
            pendingDeletions.insert(id)
            log.error("Supabase venue delete failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second backoff
        }
        publishSyncStatus()
    }

    func pushDirtyVenues() async throws {
        guard ownerUUID != nil else { return }
        let records = try store.loadAll().filter { $0.needsRemoteSync }
        guard !records.isEmpty else { return }

        log.debug("Venue sync enqueuing dirty records count=\(records.count)")

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

        let request = SupabaseVenueLibraryAPI.VenueRequest(
            id: record.id,
            ownerId: ownerUUID,
            name: record.name,
            city: record.city,
            country: record.country,
            latitude: record.latitude,
            longitude: record.longitude
        )

        do {
            let result = try await api.syncVenue(request)
            record.needsRemoteSync = false
            record.remoteUpdatedAt = result.updatedAt
            record.lastModifiedAt = dateProvider()
            record.ownerSupabaseId = ownerUUID.uuidString
            try store.context.save()
            log.debug(
                "Venue push succeeded id=\(id.uuidString, privacy: .public) updatedAt=\(self.describe(result.updatedAt), privacy: .public)"
            )
        } catch {
            pendingPushes.insert(id)
            log.error("Supabase venue push failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
        publishSyncStatus()
    }

    func pullRemoteUpdates(for ownerUUID: UUID) async throws {
        let ownerString = ownerUUID.uuidString
        let cursorBefore = describe(remoteCursor)

        log.debug(
            "Venue pull requesting owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)"
        )

        do {
            let remoteVenues = try await api.fetchVenues(ownerId: ownerUUID, updatedAfter: remoteCursor)
            log.info(
                "Venue pull received count=\(remoteVenues.count) owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)"
            )

            guard !remoteVenues.isEmpty else {
                publishSyncStatus()
                return
            }

            let existingRecords = try store.loadAll()
            var existingById = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })

            var updatedCount = 0
            var insertedCount = 0
            var skippedPendingDeletion = 0
            var skippedDirtyConflict = 0

            for remote in remoteVenues {
                if pendingDeletions.contains(remote.id) {
                    skippedPendingDeletion += 1
                    continue
                }

                if let existing = existingById[remote.id] {
                    let localDirty = existing.needsRemoteSync
                    let localRemoteDate = existing.remoteUpdatedAt ?? .distantPast

                    if localDirty && remote.updatedAt <= localRemoteDate {
                        skippedDirtyConflict += 1
                        continue
                    }

                    existing.name = remote.name
                    existing.city = remote.city
                    existing.country = remote.country
                    existing.latitude = remote.latitude
                    existing.longitude = remote.longitude
                    existing.ownerSupabaseId = remote.ownerId.uuidString
                    existing.remoteUpdatedAt = remote.updatedAt
                    existing.lastModifiedAt = dateProvider()
                    existing.needsRemoteSync = false
                    updatedCount += 1
                } else {
                    let newRecord = VenueRecord(
                        id: remote.id,
                        name: remote.name,
                        city: remote.city,
                        country: remote.country,
                        latitude: remote.latitude,
                        longitude: remote.longitude,
                        ownerSupabaseId: remote.ownerId.uuidString,
                        lastModifiedAt: dateProvider(),
                        remoteUpdatedAt: remote.updatedAt,
                        needsRemoteSync: false
                    )
                    store.context.insert(newRecord)
                    existingById[remote.id] = newRecord
                    insertedCount += 1
                }
            }

            if store.context.hasChanges {
                try store.context.save()
            }

            if let maxDate = remoteVenues.map({ $0.updatedAt }).max() {
                remoteCursor = max(remoteCursor ?? maxDate, maxDate)
            }

            log.info(
                "Venue pull applied updated=\(updatedCount) inserted=\(insertedCount) skippedPendingDeletion=\(skippedPendingDeletion) skippedDirty=\(skippedDirtyConflict) newCursor=\(self.describe(self.remoteCursor), privacy: .public)"
            )
        } catch {
            log.error(
                "Venue pull failed owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw error
        }

        publishSyncStatus()
    }
}

// MARK: - Helpers

private extension SupabaseVenueLibraryRepository {
    func publishSyncStatus() {
        let info: [String: Any] = [
            "component": "venue_library",
            "pendingPushes": pendingPushes.count,
            "pendingDeletions": pendingDeletions.count,
            "signedIn": ownerUUID != nil,
            "timestamp": dateProvider()
        ]
        NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
    }

    func applyOwnerIdentityIfNeeded(to record: VenueRecord) {
        guard let ownerUUID else { return }
        if record.ownerSupabaseId != ownerUUID.uuidString {
            record.ownerSupabaseId = ownerUUID.uuidString
            try? store.context.save()
        }
    }

    func applyOwnerIdentityIfNeeded(venueId: UUID) {
        guard let ownerUUID else { return }
        guard let records = try? store.loadAll(),
              let record = records.first(where: { $0.id == venueId }) else {
            return
        }
        applyOwnerIdentityIfNeeded(to: record)
    }

    func fetchVenue(id: UUID) throws -> VenueRecord? {
        var descriptor = FetchDescriptor<VenueRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try store.context.fetch(descriptor).first
    }

    func requireOwnerUUIDForAggregate(operation: String) throws -> UUID {
        guard let ownerUUID else {
            throw PersistenceAuthError.signedOut(operation: operation)
        }
        return ownerUUID
    }

    func describe(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return isoFormatter.string(from: date)
    }

    func describe(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}

extension SupabaseVenueLibraryRepository: AggregateVenueApplying {
    func upsertVenue(from aggregate: AggregateSnapshotPayload.Venue) throws {
        let ownerUUID = try requireOwnerUUIDForAggregate(operation: "aggregate venue upsert")
        let record = try store.upsertFromAggregate(aggregate, ownerSupabaseId: ownerUUID.uuidString)
        pendingDeletions.remove(record.id)
        backlog.removePendingDeletion(id: record.id)
        pendingPushes.insert(record.id)
        scheduleProcessingTask()
        publishSyncStatus()
    }

    func deleteVenue(id: UUID) throws {
        _ = try requireOwnerUUIDForAggregate(operation: "aggregate venue delete")
        if (try fetchVenue(id: id)) != nil {
            try store.deleteVenue(id: id)
        }
        pendingPushes.remove(id)
        pendingDeletions.insert(id)
        backlog.addPendingDeletion(id: id)
        scheduleProcessingTask()
        publishSyncStatus()
    }
}
