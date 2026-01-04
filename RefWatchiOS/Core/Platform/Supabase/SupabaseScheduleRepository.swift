//
//  SupabaseScheduleRepository.swift
//  RefWatchiOS
//
//  Wraps the SwiftData schedule store with Supabase-aware synchronisation. The
//  repository mirrors the team library implementation: local mutations remain
//  instant while background tasks push pending changes and merge remote updates
//  when identity and connectivity permit.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SupabaseScheduleRepository: ScheduleStoring {
  private let store: SwiftDataScheduleStore
  private let metadataPersistor: ScheduleMetadataPersisting
  private let api: SupabaseScheduleServing
  private let authStateProvider: SupabaseAuthStateProviding
  private let backlog: ScheduleSyncBacklogStoring
  private let dateProvider: () -> Date
  private let log = AppLog.supabase
  private let pullInterval: TimeInterval

  private var ownerUUID: UUID?
  private var authCancellable: AnyCancellable?
  private var processingTask: Task<Void, Never>?
  private var pullTask: Task<Void, Never>?
  private var pendingPushes: Set<UUID> = []
  private var pendingDeletions: Set<UUID>
  private var remoteCursor: Date?

  init(
    store: SwiftDataScheduleStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseScheduleServing,
    backlog: ScheduleSyncBacklogStoring,
    metadataPersistor: ScheduleMetadataPersisting? = nil,
    dateProvider: @escaping () -> Date = Date.init,
    pullInterval: TimeInterval = 300)
  {
    self.store = store
    self.authStateProvider = authStateProvider
    self.api = api
    self.backlog = backlog
    self.metadataPersistor = metadataPersistor ?? store
    self.dateProvider = dateProvider
    self.pullInterval = pullInterval
    self.pendingDeletions = backlog.loadPendingDeletionIDs()
    publishSyncStatus()

    if let userId = authStateProvider.currentUserId,
       let uuid = UUID(uuidString: userId)
    {
      self.ownerUUID = uuid
      publishSyncStatus()
      scheduleInitialSync()
    }

    self.authCancellable = authStateProvider.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          await self?.handleAuthState(state)
        }
      }
  }

  deinit {
    authCancellable?.cancel()
    processingTask?.cancel()
    pullTask?.cancel()
  }

  // MARK: - ScheduleStoring

  func loadAll() -> [ScheduledMatch] {
    self.store.loadAll()
  }

  func save(_ item: ScheduledMatch) throws {
    let ownerUUID = try requireOwnerUUID(operation: "save scheduled match")
    var updated = item
    if updated.ownerSupabaseId != ownerUUID.uuidString {
      updated.ownerSupabaseId = ownerUUID.uuidString
    }
    updated.needsRemoteSync = true
    try self.store.save(updated)
    enqueuePush(for: updated.id)
  }

  func delete(id: UUID) throws {
    _ = try requireOwnerUUID(operation: "delete scheduled match")
    self.pendingPushes.remove(id)
    self.pendingDeletions.insert(id)
    self.backlog.addPendingDeletion(id: id)
    try self.store.delete(id: id)
    scheduleProcessingTask()
    publishSyncStatus()
  }

  func wipeAll() throws {
    _ = try requireOwnerUUID(operation: "wipe scheduled matches")
    let existing = self.store.loadAll()
    for match in existing {
      self.pendingPushes.remove(match.id)
      self.pendingDeletions.insert(match.id)
      self.backlog.addPendingDeletion(id: match.id)
    }
    try self.store.wipeAll()
    scheduleProcessingTask()
    publishSyncStatus()
  }

  var changesPublisher: AnyPublisher<[ScheduledMatch], Never> {
    self.store.changesPublisher
  }

  func refreshFromRemote() async throws {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: "refresh scheduled matches")
    }
    do {
      try await flushPendingDeletions()
      try await pushDirtyMatches()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      self.log.error("Scheduled match refresh failed: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }
}

// MARK: - Identity Handling

extension SupabaseScheduleRepository {
  private func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      self.ownerUUID = nil
      self.remoteCursor = nil
      self.processingTask?.cancel()
      self.processingTask = nil
      self.pullTask?.cancel()
      self.pullTask = nil
      self.pendingPushes.removeAll()
      self.pendingDeletions.removeAll()
      self.backlog.clearAll()
      do {
        try self.store.wipeAllForLogout()
        self.log.notice("Cleared scheduled matches after sign-out")
      } catch {
        self.log.error("Failed to wipe scheduled matches on sign-out: \(error.localizedDescription, privacy: .public)")
      }
      publishSyncStatus()
    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        self.log.error("Schedule sync received non-UUID Supabase id: \(userId, privacy: .public)")
        return
      }
      self.ownerUUID = uuid
      publishSyncStatus()
      self.scheduleInitialSync()
    }
  }

  private func scheduleInitialSync() {
    scheduleProcessingTask()
    self.startPeriodicPull()
    Task { [weak self] in
      await self?.performInitialSync()
    }
  }

  private func performInitialSync() async {
    guard let ownerUUID else { return }
    do {
      try await flushPendingDeletions()
      try await pushDirtyMatches()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      self.log.error("Initial schedule sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func startPeriodicPull() {
    self.pullTask?.cancel()
    guard self.ownerUUID != nil else { return }
    self.pullTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(self.pullInterval * 1_000_000_000))
        guard !Task.isCancelled, let ownerUUID = self.ownerUUID else { continue }
        do {
          try await self.pullRemoteUpdates(for: ownerUUID)
        } catch {
          self.log.error("Periodic schedule pull failed: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }
}

// MARK: - Queue Processing

extension SupabaseScheduleRepository {
  fileprivate enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  private func enqueuePush(for matchId: UUID) {
    self.pendingPushes.insert(matchId)
    applyOwnerIdentityIfNeeded(for: matchId)
    self.scheduleProcessingTask()
    publishSyncStatus()
  }

  private func scheduleProcessingTask() {
    guard self.processingTask == nil else { return }
    self.processingTask = Task { [weak self] in
      await self?.drainQueues()
    }
  }

  private func drainQueues() async {
    defer {
      Task { @MainActor in self.processingTask = nil }
    }

    while true {
      guard let operation = await nextOperation() else { return }
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
      guard self.ownerUUID != nil else { return nil }
      if let deletionId = pendingDeletions.popFirst() {
        return .delete(deletionId)
      }
      if let pushId = pendingPushes.popFirst() {
        return .push(pushId)
      }
      return nil
    }
  }
}

// MARK: - Remote Operations

extension SupabaseScheduleRepository {
  private func flushPendingDeletions() async throws {
    guard self.ownerUUID != nil else { return }
    while let deletionId = pendingDeletions.popFirst() {
      await self.performRemoteDeletion(id: deletionId)
    }
  }

  private func performRemoteDeletion(id: UUID) async {
    do {
      try await self.api.deleteScheduledMatch(id: id)
      self.backlog.removePendingDeletion(id: id)
    } catch {
      self.pendingDeletions.insert(id)
      self.log.error(
        "Supabase schedule delete failed id=\(id.uuidString, privacy: .public) " +
          "error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    publishSyncStatus()
  }

  private func performRemotePush(id: UUID) async {
    guard let ownerUUID else { return }
    guard let record = try? store.record(id: id) else { return }
    guard record.needsRemoteSync else { return }

    let request = makeUpsertRequest(for: record, ownerUUID: ownerUUID)

    do {
      let result = try await api.syncScheduledMatch(request)
      record.applyRemoteSyncMetadata(
        ownerId: ownerUUID.uuidString,
        remoteUpdatedAt: result.updatedAt,
        status: request.status,
        synchronizedAt: self.dateProvider())
      try self.store.context.save()
      self.metadataPersistor.publishSnapshot()
      self.remoteCursor = max(self.remoteCursor ?? result.updatedAt, result.updatedAt)
    } catch {
      self.pendingPushes.insert(id)
      self.log.error(
        "Supabase schedule push failed id=\(id.uuidString, privacy: .public) " +
          "error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    publishSyncStatus()
  }

  private func pushDirtyMatches() async throws {
    guard self.ownerUUID != nil else { return }
    let all = self.store.loadAll()
    let dirty = all.filter(\.needsRemoteSync)
    guard dirty.isEmpty == false else { return }
    for match in dirty {
      self.pendingPushes.insert(match.id)
      applyOwnerIdentityIfNeeded(for: match.id)
    }
    self.scheduleProcessingTask()
    publishSyncStatus()
    try? await Task.sleep(nanoseconds: 200_000_000)
  }

  private func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let remote = try await api.fetchScheduledMatches(ownerId: ownerUUID, updatedAfter: self.remoteCursor)
    guard remote.isEmpty == false else { return }
    let filtered = remote.filter { !self.pendingDeletions.contains($0.id) }
    guard filtered.isEmpty == false else { return }
    try mergeRemoteMatches(filtered, ownerUUID: ownerUUID)
    if let maxDate = filtered.map(\.updatedAt).max() {
      self.remoteCursor = max(self.remoteCursor ?? maxDate, maxDate)
    }
    publishSyncStatus()
  }
}

// MARK: - Local Merge Helpers

extension SupabaseScheduleRepository {
  private func mergeRemoteMatches(_ remoteMatches: [SupabaseScheduleAPI.RemoteScheduledMatch], ownerUUID: UUID) throws {
    var didChange = false
    for remote in remoteMatches {
      if let record = try store.record(id: remote.id) {
        let remoteUpdatedAt = remote.updatedAt
        let currentRemote = record.remoteUpdatedAt ?? .distantPast
        if remoteUpdatedAt <= currentRemote, record.needsRemoteSync == false {
          continue
        }
        self.apply(remote: remote, to: record, ownerUUID: ownerUUID)
        didChange = true
      } else {
        try self.insertRemoteMatch(remote, ownerUUID: ownerUUID)
        didChange = true
      }
    }
    if didChange {
      try self.store.context.save()
      self.metadataPersistor.publishSnapshot()
    }
  }

  private func insertRemoteMatch(_ remote: SupabaseScheduleAPI.RemoteScheduledMatch, ownerUUID: UUID) throws {
    let record = ScheduledMatchRecord(
      id: remote.id,
      kickoff: remote.kickoffAt,
      homeName: remote.homeTeamName,
      awayName: remote.awayTeamName,
      competition: remote.competitionName,
      notes: remote.notes,
      status: remote.status,
      ownerSupabaseId: ownerUUID.uuidString,
      lastModifiedAt: self.dateProvider(),
      remoteUpdatedAt: remote.updatedAt,
      needsRemoteSync: false,
      sourceDeviceId: remote.sourceDeviceId)
    self.store.context.insert(record)
  }

  private func apply(
    remote: SupabaseScheduleAPI.RemoteScheduledMatch,
    to record: ScheduledMatchRecord,
    ownerUUID: UUID)
  {
    record.homeName = remote.homeTeamName
    record.awayName = remote.awayTeamName
    record.kickoff = remote.kickoffAt
    record.competition = remote.competitionName
    record.notes = remote.notes
    record.status = remote.status
    record.sourceDeviceId = remote.sourceDeviceId
    record.applyRemoteSyncMetadata(
      ownerId: ownerUUID.uuidString,
      remoteUpdatedAt: remote.updatedAt,
      status: remote.status,
      synchronizedAt: self.dateProvider())
  }

  private func makeUpsertRequest(for record: ScheduledMatchRecord, ownerUUID: UUID) -> SupabaseScheduleAPI
  .UpsertRequest {
    SupabaseScheduleAPI.UpsertRequest(
      id: record.id,
      ownerId: ownerUUID,
      homeTeamName: record.homeName,
      awayTeamName: record.awayName,
      kickoffAt: record.kickoff,
      status: record.status,
      competitionId: nil,
      competitionName: record.competition,
      venueId: nil,
      venueName: nil,
      homeTeamId: record.homeTeam?.id,
      awayTeamId: record.awayTeam?.id,
      notes: record.notes,
      sourceDeviceId: record.sourceDeviceId)
  }

  private func applyOwnerIdentityIfNeeded(for matchId: UUID) {
    guard let ownerUUID else { return }
    guard let record = try? store.record(id: matchId) else { return }
    if record.ownerSupabaseId != ownerUUID.uuidString {
      record.ownerSupabaseId = ownerUUID.uuidString
      try? self.store.context.save()
      self.metadataPersistor.publishSnapshot()
    }
  }

  private func publishSyncStatus() {
    let info: [String: Any] = [
      "component": "schedule",
      "pendingPushes": pendingPushes.count,
      "pendingDeletions": self.pendingDeletions.count,
      "signedIn": self.ownerUUID != nil,
      "timestamp": self.dateProvider(),
    ]
    NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
  }

  private func requireOwnerUUID(operation: String) throws -> UUID {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
    return ownerUUID
  }
}

extension SupabaseScheduleRepository: AggregateScheduleApplying {
  func upsertSchedule(from aggregate: AggregateSnapshotPayload.Schedule) throws {
    let ownerUUID = try requireOwnerUUID(operation: "aggregate schedule upsert")
    let record = try store.upsertFromAggregate(aggregate, ownerSupabaseId: ownerUUID.uuidString)
    self.pendingDeletions.remove(record.id)
    self.backlog.removePendingDeletion(id: record.id)
    self.pendingPushes.insert(record.id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }

  func deleteSchedule(id: UUID) throws {
    _ = try self.requireOwnerUUID(operation: "aggregate schedule delete")
    try self.store.deleteSchedule(id: id)
    self.pendingPushes.remove(id)
    self.pendingDeletions.insert(id)
    self.backlog.addPendingDeletion(id: id)
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }
}
