//
//  SupabaseCompetitionLibraryRepository.swift
//  RefWatchiOS
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
  private let isoFormatter: ISO8601DateFormatter

  private var authCancellable: AnyCancellable?
  private var ownerUUID: UUID?
  private var pendingPushes: Set<UUID> = []
  private var pendingDeletions: Set<UUID>
  private var processingTask: Task<Void, Never>?
  private var remoteCursor: Date?

  var changesPublisher: AnyPublisher<[CompetitionRecord], Never> {
    self.store.changesPublisher
  }

  init(
    store: SwiftDataCompetitionLibraryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseCompetitionLibraryServing,
    backlog: CompetitionLibrarySyncBacklogStoring,
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

  // MARK: - CompetitionLibraryStoring

  func loadAll() throws -> [CompetitionRecord] {
    try self.store.loadAll()
  }

  func search(query: String) throws -> [CompetitionRecord] {
    try self.store.search(query: query)
  }

  func create(name: String, level: String?) throws -> CompetitionRecord {
    let record = try store.create(name: name, level: level)
    applyOwnerIdentityIfNeeded(to: record)
    enqueuePush(for: record.id)
    return record
  }

  func update(_ competition: CompetitionRecord) throws {
    try self.store.update(competition)
    applyOwnerIdentityIfNeeded(to: competition)
    enqueuePush(for: competition.id)
  }

  func delete(_ competition: CompetitionRecord) throws {
    let competitionId = competition.id
    try self.store.delete(competition)
    self.pendingPushes.remove(competitionId)
    self.pendingDeletions.insert(competitionId)
    self.backlog.addPendingDeletion(id: competitionId)
    scheduleProcessingTask()
    publishSyncStatus()
  }

  func wipeAllForLogout() throws {
    try self.store.wipeAllForLogout()
  }

  func refreshFromRemote() async throws {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: "refresh competitions")
    }
    try await pullRemoteUpdates(for: ownerUUID)
  }
}

// MARK: - Identity Handling & Sync Scheduling

extension SupabaseCompetitionLibraryRepository {
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
        self.log.notice("Cleared local competition library after sign-out")
      } catch {
        self.log.error("Failed to wipe competitions on sign-out: \(error.localizedDescription, privacy: .public)")
      }
      publishSyncStatus()

    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        self.log.error("Competition sync received non-UUID Supabase id: \(userId, privacy: .public)")
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
      "Competition initial sync started owner=\(ownerString, privacy: .public) cursor=\(startingCursor, privacy: .public) pendingPush=\(self.pendingPushes.count) pendingDelete=\(self.pendingDeletions.count)")

    do {
      if !self.pendingDeletions.isEmpty {
        self.log.debug("Competition initial sync flushing pending deletions count=\(self.pendingDeletions.count)")
      }
      try await flushPendingDeletions()

      self.log.debug("Competition initial sync scanning for dirty competitions")
      try await pushDirtyCompetitions()
      self.log.debug("Competition initial sync queued pending pushes=\(self.pendingPushes.count)")

      self.log.debug(
        "Competition initial sync pulling remote updates cursor=\(self.describe(self.remoteCursor), privacy: .public)")
      try await pullRemoteUpdates(for: ownerUUID)

      self.log.notice(
        "Competition initial sync finished owner=\(ownerString, privacy: .public) cursor=\(self.describe(self.remoteCursor), privacy: .public) pendingPush=\(self.pendingPushes.count) pendingDelete=\(self.pendingDeletions.count)")
    } catch {
      self.log.error(
        "Initial competition sync failed owner=\(ownerString, privacy: .public) cursor=\(startingCursor, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }
  }
}

// MARK: - Queue Processing

extension SupabaseCompetitionLibraryRepository {
  fileprivate enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  private func enqueuePush(for competitionId: UUID) {
    self.pendingPushes.insert(competitionId)
    applyOwnerIdentityIfNeeded(competitionId: competitionId)
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

extension SupabaseCompetitionLibraryRepository {
  private func flushPendingDeletions() async throws {
    while let deletionId = pendingDeletions.popFirst() {
      await self.performRemoteDeletion(id: deletionId)
      try await Task.sleep(nanoseconds: 10_000_000) // Small delay between operations
    }
  }

  private func performRemoteDeletion(id: UUID) async {
    do {
      try await self.api.deleteCompetition(competitionId: id)
      self.backlog.removePendingDeletion(id: id)
    } catch {
      self.pendingDeletions.insert(id)
      self.log
        .error(
          "Supabase competition delete failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second backoff
    }
    publishSyncStatus()
  }

  private func pushDirtyCompetitions() async throws {
    guard self.ownerUUID != nil else { return }
    let records = try store.loadAll().filter(\.needsRemoteSync)
    guard !records.isEmpty else { return }

    self.log.debug("Competition sync enqueuing dirty records count=\(records.count)")

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

    let request = SupabaseCompetitionLibraryAPI.CompetitionRequest(
      id: record.id,
      ownerId: ownerUUID,
      name: record.name,
      level: record.level)

    do {
      let result = try await api.syncCompetition(request)
      record.needsRemoteSync = false
      record.remoteUpdatedAt = result.updatedAt
      record.lastModifiedAt = self.dateProvider()
      record.ownerSupabaseId = ownerUUID.uuidString
      try self.store.context.save()
      self.log.debug(
        "Competition push succeeded id=\(id.uuidString, privacy: .public) updatedAt=\(self.describe(result.updatedAt), privacy: .public)")
    } catch {
      self.pendingPushes.insert(id)
      self.log
        .error(
          "Supabase competition push failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }
    publishSyncStatus()
  }

  private func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let ownerString = ownerUUID.uuidString
    let cursorBefore = describe(remoteCursor)

    self.log.debug(
      "Competition pull requesting owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)")

    do {
      let remoteCompetitions = try await api.fetchCompetitions(ownerId: ownerUUID, updatedAfter: self.remoteCursor)
      self.log.info(
        "Competition pull received count=\(remoteCompetitions.count) owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)")

      guard !remoteCompetitions.isEmpty else {
        publishSyncStatus()
        return
      }

      let existingRecords = try store.loadAll()
      var existingById = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })

      var updatedCount = 0
      var insertedCount = 0
      var skippedPendingDeletion = 0
      var skippedDirtyConflict = 0

      for remote in remoteCompetitions {
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
          existing.level = remote.level
          existing.ownerSupabaseId = remote.ownerId.uuidString
          existing.remoteUpdatedAt = remote.updatedAt
          existing.lastModifiedAt = self.dateProvider()
          existing.needsRemoteSync = false
          updatedCount += 1
        } else {
          let newRecord = CompetitionRecord(
            id: remote.id,
            name: remote.name,
            level: remote.level,
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

      if let maxDate = remoteCompetitions.map(\.updatedAt).max() {
        self.remoteCursor = max(self.remoteCursor ?? maxDate, maxDate)
      }

      self.log.info(
        "Competition pull applied updated=\(updatedCount) inserted=\(insertedCount) skippedPendingDeletion=\(skippedPendingDeletion) skippedDirty=\(skippedDirtyConflict) newCursor=\(self.describe(self.remoteCursor), privacy: .public)")
    } catch {
      self.log.error(
        "Competition pull failed owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      throw error
    }

    publishSyncStatus()
  }
}

// MARK: - Helpers

extension SupabaseCompetitionLibraryRepository {
  private func publishSyncStatus() {
    let info: [String: Any] = [
      "component": "competition_library",
      "pendingPushes": pendingPushes.count,
      "pendingDeletions": self.pendingDeletions.count,
      "signedIn": self.ownerUUID != nil,
      "timestamp": self.dateProvider(),
    ]
    NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
  }

  private func applyOwnerIdentityIfNeeded(to record: CompetitionRecord) {
    guard let ownerUUID else { return }
    if record.ownerSupabaseId != ownerUUID.uuidString {
      record.ownerSupabaseId = ownerUUID.uuidString
      try? self.store.context.save()
    }
  }

  private func applyOwnerIdentityIfNeeded(competitionId: UUID) {
    guard self.ownerUUID != nil else { return }
    guard let records = try? store.loadAll(),
          let record = records.first(where: { $0.id == competitionId })
    else {
      return
    }
    self.applyOwnerIdentityIfNeeded(to: record)
  }

  private func fetchCompetition(id: UUID) throws -> CompetitionRecord? {
    var descriptor = FetchDescriptor<CompetitionRecord>(predicate: #Predicate { $0.id == id })
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

extension SupabaseCompetitionLibraryRepository: AggregateCompetitionApplying {
  func upsertCompetition(from aggregate: AggregateSnapshotPayload.Competition) throws {
    let ownerUUID = try requireOwnerUUIDForAggregate(operation: "aggregate competition upsert")
    let record = try store.upsertFromAggregate(aggregate, ownerSupabaseId: ownerUUID.uuidString)
    self.pendingDeletions.remove(record.id)
    self.backlog.removePendingDeletion(id: record.id)
    self.pendingPushes.insert(record.id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }

  func deleteCompetition(id: UUID) throws {
    _ = try self.requireOwnerUUIDForAggregate(operation: "aggregate competition delete")
    if try (self.fetchCompetition(id: id)) != nil {
      try self.store.deleteCompetition(id: id)
    }
    self.pendingPushes.remove(id)
    self.pendingDeletions.insert(id)
    self.backlog.addPendingDeletion(id: id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }
}
