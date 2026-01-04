//
//  SupabaseVenueLibraryRepository.swift
//  RefWatchiOS
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
    self.store.changesPublisher
  }

  init(
    store: SwiftDataVenueLibraryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseVenueLibraryServing,
    backlog: VenueLibrarySyncBacklogStoring,
    dateProvider: @escaping () -> Date = Date.init)
  {
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
       let uuid = UUID(uuidString: userId)
    {
      self.ownerUUID = uuid
    }

    self.authCancellable = authStateProvider.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          await self?.handleAuthState(state)
        }
      }

    if self.ownerUUID != nil {
      scheduleInitialSync()
    }
  }

  deinit {
    authCancellable?.cancel()
    processingTask?.cancel()
  }

  // MARK: - VenueLibraryStoring

  func loadAll() throws -> [VenueRecord] {
    try self.store.loadAll()
  }

  func search(query: String) throws -> [VenueRecord] {
    try self.store.search(query: query)
  }

  func create(name: String, city: String?, country: String?) throws -> VenueRecord {
    let record = try store.create(name: name, city: city, country: country)
    applyOwnerIdentityIfNeeded(to: record)
    enqueuePush(for: record.id)
    return record
  }

  func update(_ venue: VenueRecord) throws {
    try self.store.update(venue)
    applyOwnerIdentityIfNeeded(to: venue)
    enqueuePush(for: venue.id)
  }

  func delete(_ venue: VenueRecord) throws {
    let venueId = venue.id
    try self.store.delete(venue)
    self.pendingPushes.remove(venueId)
    self.pendingDeletions.insert(venueId)
    self.backlog.addPendingDeletion(id: venueId)
    scheduleProcessingTask()
    publishSyncStatus()
  }

  func wipeAllForLogout() throws {
    try self.store.wipeAllForLogout()
  }

  func refreshFromRemote() async throws {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: "refresh venues")
    }
    try await pullRemoteUpdates(for: ownerUUID)
  }
}

// MARK: - Identity Handling & Sync Scheduling

extension SupabaseVenueLibraryRepository {
  private func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      self.ownerUUID = nil
      self.remoteCursor = nil
      self.processingTask?.cancel()
      self.processingTask = nil
      self.pendingPushes.removeAll()
      self.pendingDeletions.removeAll()
      self.backlog.clearAll()
      do {
        try self.store.wipeAllForLogout()
        self.log.notice("Cleared local venue library after sign-out")
      } catch {
        self.log.error("Failed to wipe venues on sign-out: \(error.localizedDescription, privacy: .public)")
      }
      publishSyncStatus()

    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        self.log.error("Venue sync received non-UUID Supabase id: \(userId, privacy: .public)")
        return
      }
      self.ownerUUID = uuid
      self.remoteCursor = nil
      publishSyncStatus()
      self.scheduleInitialSync()
    }
  }

  private func scheduleInitialSync() {
    scheduleProcessingTask()
    Task { [weak self] in
      await self?.performInitialSync()
    }
  }

  private func performInitialSync() async {
    guard let ownerUUID else { return }
    let ownerString = ownerUUID.uuidString
    let startingCursor = describe(remoteCursor)

    self.log.notice(
      "Venue initial sync started owner=\(ownerString, privacy: .public) " +
        "cursor=\(startingCursor, privacy: .public) " +
        "pendingPush=\(self.pendingPushes.count) " +
        "pendingDelete=\(self.pendingDeletions.count)")

    do {
      if !self.pendingDeletions.isEmpty {
        self.log.debug("Venue initial sync flushing pending deletions count=\(self.pendingDeletions.count)")
      }
      try await flushPendingDeletions()

      self.log.debug("Venue initial sync scanning for dirty venues")
      try await pushDirtyVenues()
      self.log.debug("Venue initial sync queued pending pushes=\(self.pendingPushes.count)")

      self.log
        .debug("Venue initial sync pulling remote updates cursor=\(self.describe(self.remoteCursor), privacy: .public)")
      try await pullRemoteUpdates(for: ownerUUID)

      self.log.notice(
        "Venue initial sync finished owner=\(ownerString, privacy: .public) " +
          "cursor=\(self.describe(self.remoteCursor), privacy: .public) " +
          "pendingPush=\(self.pendingPushes.count) " +
          "pendingDelete=\(self.pendingDeletions.count)")
    } catch {
      self.log.error(
        "Initial venue sync failed owner=\(ownerString, privacy: .public) " +
          "cursor=\(startingCursor, privacy: .public) " +
          "error=\(error.localizedDescription, privacy: .public)")
    }
  }
}

// MARK: - Queue Processing

extension SupabaseVenueLibraryRepository {
  fileprivate enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  private func enqueuePush(for venueId: UUID) {
    self.pendingPushes.insert(venueId)
    applyOwnerIdentityIfNeeded(venueId: venueId)
    self.scheduleProcessingTask()
    publishSyncStatus()
  }

  private func scheduleProcessingTask() {
    guard self.processingTask == nil else { return }
    self.processingTask = Task { [weak self] in
      guard let self else { return }
      await self.drainQueues()
      await MainActor.run { self.processingTask = nil }
    }
  }

  private func drainQueues() async {
    while !Task.isCancelled {
      guard let operation = await nextOperation() else { break }
      switch operation {
      case let .delete(id):
        await performRemoteDeletion(id: id)
      case let .push(id):
        await performRemotePush(id: id)
      }
    }
  }

  private func nextOperation() async -> SyncOperation? {
    await MainActor.run {
      if let deletion = pendingDeletions.popFirst() {
        return .delete(deletion)
      }
      guard self.ownerUUID != nil else { return nil }
      if let push = pendingPushes.popFirst() {
        return .push(push)
      }
      return nil
    }
  }
}

// MARK: - Remote Operations

extension SupabaseVenueLibraryRepository {
  private func flushPendingDeletions() async throws {
    while let deletionId = pendingDeletions.popFirst() {
      await self.performRemoteDeletion(id: deletionId)
      try await Task.sleep(nanoseconds: 10_000_000) // Small delay between operations
    }
  }

  private func performRemoteDeletion(id: UUID) async {
    do {
      try await self.api.deleteVenue(venueId: id)
      self.backlog.removePendingDeletion(id: id)
    } catch {
      self.pendingDeletions.insert(id)
      self.log
        .error(
          "Supabase venue delete failed id=\(id.uuidString, privacy: .public) " +
            "error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second backoff
    }
    publishSyncStatus()
  }

  private func pushDirtyVenues() async throws {
    guard self.ownerUUID != nil else { return }
    let records = try store.loadAll().filter(\.needsRemoteSync)
    guard !records.isEmpty else { return }

    self.log.debug("Venue sync enqueuing dirty records count=\(records.count)")

    for record in records {
      self.pendingPushes.insert(record.id)
      applyOwnerIdentityIfNeeded(to: record)
    }
    self.scheduleProcessingTask()
    publishSyncStatus()
  }

  private func performRemotePush(id: UUID) async {
    guard let ownerUUID else {
      self.pendingPushes.insert(id)
      return
    }

    guard let records = try? store.loadAll(),
          let record = records.first(where: { $0.id == id })
    else {
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
      longitude: record.longitude)

    do {
      let result = try await api.syncVenue(request)
      record.needsRemoteSync = false
      record.remoteUpdatedAt = result.updatedAt
      record.lastModifiedAt = self.dateProvider()
      record.ownerSupabaseId = ownerUUID.uuidString
      try self.store.context.save()
      self.log.debug(
        "Venue push succeeded id=\(id.uuidString, privacy: .public) " +
          "updatedAt=\(self.describe(result.updatedAt), privacy: .public)")
    } catch {
      self.pendingPushes.insert(id)
      self.log
        .error(
          "Supabase venue push failed id=\(id.uuidString, privacy: .public) " +
            "error=\(error.localizedDescription, privacy: .public)")
    }
    publishSyncStatus()
  }

  private func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let ownerString = ownerUUID.uuidString
    let cursorBefore = describe(remoteCursor)

    self.log.debug(
      "Venue pull requesting owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)")

    do {
      let remoteVenues = try await api.fetchVenues(ownerId: ownerUUID, updatedAfter: self.remoteCursor)
      self.log.info(
        "Venue pull received count=\(remoteVenues.count) " +
          "owner=\(ownerString, privacy: .public) " +
          "cursor=\(cursorBefore, privacy: .public)")

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
        if self.pendingDeletions.contains(remote.id) {
          skippedPendingDeletion += 1
          continue
        }

        if let existing = existingById[remote.id] {
          let localDirty = existing.needsRemoteSync
          let localRemoteDate = existing.remoteUpdatedAt ?? .distantPast

          if localDirty, remote.updatedAt <= localRemoteDate {
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
          existing.lastModifiedAt = self.dateProvider()
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
            lastModifiedAt: self.dateProvider(),
            remoteUpdatedAt: remote.updatedAt,
            needsRemoteSync: false)
          self.store.context.insert(newRecord)
          existingById[remote.id] = newRecord
          insertedCount += 1
        }
      }

      if self.store.context.hasChanges {
        try self.store.context.save()
      }

      if let maxDate = remoteVenues.map(\.updatedAt).max() {
        self.remoteCursor = max(self.remoteCursor ?? maxDate, maxDate)
      }

      self.log.info(
        "Venue pull applied updated=\(updatedCount) inserted=\(insertedCount) " +
          "skippedPendingDeletion=\(skippedPendingDeletion) " +
          "skippedDirty=\(skippedDirtyConflict) " +
          "newCursor=\(self.describe(self.remoteCursor), privacy: .public)")
    } catch {
      self.log.error(
        "Venue pull failed owner=\(ownerString, privacy: .public) " +
          "cursor=\(cursorBefore, privacy: .public) " +
          "error=\(error.localizedDescription, privacy: .public)")
      throw error
    }

    publishSyncStatus()
  }
}

// MARK: - Helpers

extension SupabaseVenueLibraryRepository {
  private func publishSyncStatus() {
    let info: [String: Any] = [
      "component": "venue_library",
      "pendingPushes": pendingPushes.count,
      "pendingDeletions": self.pendingDeletions.count,
      "signedIn": self.ownerUUID != nil,
      "timestamp": self.dateProvider(),
    ]
    NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
  }

  private func applyOwnerIdentityIfNeeded(to record: VenueRecord) {
    guard let ownerUUID else { return }
    if record.ownerSupabaseId != ownerUUID.uuidString {
      record.ownerSupabaseId = ownerUUID.uuidString
      try? self.store.context.save()
    }
  }

  private func applyOwnerIdentityIfNeeded(venueId: UUID) {
    guard self.ownerUUID != nil else { return }
    guard let records = try? store.loadAll(),
          let record = records.first(where: { $0.id == venueId })
    else {
      return
    }
    self.applyOwnerIdentityIfNeeded(to: record)
  }

  private func fetchVenue(id: UUID) throws -> VenueRecord? {
    var descriptor = FetchDescriptor<VenueRecord>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try self.store.context.fetch(descriptor).first
  }

  private func requireOwnerUUIDForAggregate(operation: String) throws -> UUID {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
    return ownerUUID
  }

  private func describe(_ date: Date?) -> String {
    guard let date else { return "nil" }
    return self.isoFormatter.string(from: date)
  }

  private func describe(_ date: Date) -> String {
    self.isoFormatter.string(from: date)
  }
}

extension SupabaseVenueLibraryRepository: AggregateVenueApplying {
  func upsertVenue(from aggregate: AggregateSnapshotPayload.Venue) throws {
    let ownerUUID = try requireOwnerUUIDForAggregate(operation: "aggregate venue upsert")
    let record = try store.upsertFromAggregate(aggregate, ownerSupabaseId: ownerUUID.uuidString)
    self.pendingDeletions.remove(record.id)
    self.backlog.removePendingDeletion(id: record.id)
    self.pendingPushes.insert(record.id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }

  func deleteVenue(id: UUID) throws {
    _ = try self.requireOwnerUUIDForAggregate(operation: "aggregate venue delete")
    if try (self.fetchVenue(id: id)) != nil {
      try self.store.deleteVenue(id: id)
    }
    self.pendingPushes.remove(id)
    self.pendingDeletions.insert(id)
    self.backlog.addPendingDeletion(id: id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }
}
