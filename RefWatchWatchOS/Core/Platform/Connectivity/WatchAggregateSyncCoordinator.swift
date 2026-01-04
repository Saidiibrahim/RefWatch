//
//  WatchAggregateSyncCoordinator.swift
//  RefWatchWatchOS
//
//  Handles aggregate snapshot ingestion, chunk assembly, and delta outbox maintenance.
//

import Foundation
import OSLog
import RefWatchCore

@MainActor
final class WatchAggregateSyncCoordinator {
  private let libraryStore: WatchAggregateLibraryStore
  private let chunkStore: WatchAggregateSnapshotChunkStore
  private let deltaStore: WatchAggregateDeltaOutboxStore
  private let decoder: JSONDecoder
  private let log = Logger(subsystem: "RefWatchWatchOS", category: "aggregateSync")

  var statusDidChange: ((AggregateSyncStatusRecord) -> Void)?
  var libraryDidChange: (() -> Void)?

  init(
    libraryStore: WatchAggregateLibraryStore,
    chunkStore: WatchAggregateSnapshotChunkStore,
    deltaStore: WatchAggregateDeltaOutboxStore,
    decoder: JSONDecoder = AggregateSyncCoding.makeDecoder())
  {
    self.libraryStore = libraryStore
    self.chunkStore = chunkStore
    self.deltaStore = deltaStore
    self.decoder = decoder
  }

  func ingestSnapshotData(_ data: Data) {
    do {
      let payload = try decoder.decode(AggregateSnapshotPayload.self, from: data)
      try ingestSnapshotPayload(payload, rawData: data)
    } catch {
      self.log.error("Failed to decode aggregate snapshot: \(error.localizedDescription, privacy: .public)")
    }
  }

  func enqueueDeltaEnvelope(_ envelope: AggregateDeltaEnvelope) {
    do {
      try self.deltaStore.enqueue(envelope)
      updateQueuedDeltaCount()
    } catch {
      self.log.error("Failed to enqueue delta envelope: \(error.localizedDescription, privacy: .public)")
    }
  }

  func pendingDeltaEnvelopes() -> [AggregateDeltaEnvelope] {
    do {
      return try self.deltaStore.pendingDeltas().compactMap { record in
        guard
          let entity = AggregateSyncEntity(rawValue: record.entityRaw),
          let action = AggregateDeltaAction(rawValue: record.actionRaw),
          let origin = AggregateSyncOrigin(rawValue: record.originRaw)
        else {
          self.log
            .error(
              "Dropping delta with unknown metadata " +
                "entity=\(record.entityRaw, privacy: .public) " +
                "action=\(record.actionRaw, privacy: .public)")
          return nil
        }
        return AggregateDeltaEnvelope(
          schemaVersion: AggregateSyncSchema.currentVersion,
          id: record.id,
          entity: entity,
          action: action,
          payload: record.payloadData,
          modifiedAt: record.modifiedAt,
          origin: origin,
          dependencies: record.dependencies,
          idempotencyKey: record.idempotencyKey,
          requiresSnapshotRefresh: record.requiresSnapshotRefresh)
      }
    } catch {
      self.log.error("Failed to load pending delta envelopes: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }

  func currentStatus() -> AggregateSyncStatusRecord {
    self.libraryStore.loadOrCreateStatus()
  }

  func markDeltasAttempted(ids: [UUID]) {
    do {
      try self.deltaStore.markAttempted(ids: ids)
    } catch {
      self.log.error("Failed to mark delta attempt: \(error.localizedDescription, privacy: .public)")
    }
  }

  func applyManualSyncStatus(_ message: ManualSyncStatusMessage) {
    mutateStatus { status in
      status.reachable = message.reachable
      status.queuedSnapshots = message.queued
      status.queuedDeltas = message.queuedDeltas
      status.pendingSnapshotChunks = message.pendingSnapshotChunks
      status.lastSnapshotGeneratedAt = message.lastSnapshot ?? status.lastSnapshotGeneratedAt
    }
  }

  func wipeAllData() {
    do {
      try self.libraryStore.wipeAll()
      try self.chunkStore.reset()
      try self.deltaStore.removeAll()
      notifyStatusChange()
      self.libraryDidChange?()
    } catch {
      self.log.error("Failed to wipe aggregate state: \(error.localizedDescription, privacy: .public)")
    }
  }
}

extension WatchAggregateSyncCoordinator {
  private func ingestSnapshotPayload(_ payload: AggregateSnapshotPayload, rawData: Data) throws {
    guard self.shouldProcess(payload: payload) else {
      if payload.chunk != nil {
        try? self.chunkStore.removeChunks(for: payload.generatedAt)
      }
      return
    }

    if let chunk = payload.chunk {
      if chunk.index == 0 {
        try self.chunkStore.reset()
      }
      let records = try chunkStore.saveChunk(data: rawData, payload: payload)
      let remaining = max(chunk.count - records.count, 0)
      self.mutateStatus { status in
        status.pendingSnapshotChunks = remaining
        status.lastSnapshotGeneratedAt = payload.generatedAt
        if let settings = payload.settings {
          status.reachable = settings.connectivityStatus == .reachable
        }
        if let settings = payload.settings {
          status.lastConnectivityStatusRaw = settings.connectivityStatus.rawValue
          status.lastSupabaseSync = settings.lastSuccessfulSupabaseSync
          status.requiresBackfill = settings.requiresBackfill
        }
      }
      guard remaining == 0, records.count == chunk.count else { return }
      let assembled = try assembleSnapshot(from: records)
      try chunkStore.removeChunks(for: payload.generatedAt)
      try self.applySnapshot(assembled)
    } else {
      try self.chunkStore.reset()
      try self.chunkStore.removeChunks(for: payload.generatedAt)
      try self.applySnapshot(payload)
    }
  }

  private func applySnapshot(_ payload: AggregateSnapshotPayload) throws {
    try self.libraryStore.replaceLibrary(with: payload)
    let ackIds = Array(Set(payload.acknowledgedChangeIds))
    if ackIds.isEmpty == false {
      try self.deltaStore.markAcknowledged(ids: ackIds)
    }
    let pendingDeltaCount = (try? self.deltaStore.pendingDeltas().count) ?? 0
    if ackIds.isEmpty == false {
      self.log.debug("Acknowledged \(ackIds.count, privacy: .public) aggregate delta(s)")
    }
    self.mutateStatus { status in
      status.pendingSnapshotChunks = 0
      status.lastSnapshotGeneratedAt = payload.generatedAt
      status.lastSnapshotAppliedAt = Date()
      status.queuedSnapshots = 0
      status.queuedDeltas = pendingDeltaCount
      if let settings = payload.settings {
        status.reachable = settings.connectivityStatus == .reachable
        status.lastConnectivityStatusRaw = settings.connectivityStatus.rawValue
        status.lastSupabaseSync = settings.lastSuccessfulSupabaseSync
        status.requiresBackfill = settings.requiresBackfill
      } else {
        status.requiresBackfill = false
      }
    }
    self.libraryDidChange?()
  }

  private func assembleSnapshot(from records: [AggregateSnapshotChunkRecord]) throws -> AggregateSnapshotPayload {
    let partials = try records.sorted { $0.index < $1.index }.map { record in
      try self.decoder.decode(AggregateSnapshotPayload.self, from: record.data)
    }
    guard let first = partials.first else {
      throw AggregateSyncPayloadError.missingPayload
    }

    var teams: [AggregateSnapshotPayload.Team] = []
    var competitions: [AggregateSnapshotPayload.Competition] = []
    var venues: [AggregateSnapshotPayload.Venue] = []
    var schedules: [AggregateSnapshotPayload.Schedule] = []
    var acknowledged = Set<UUID>()
    var lastSyncedAt = first.lastSyncedAt
    var settings: AggregateSnapshotPayload.Settings?
    var history: [AggregateSnapshotPayload.HistorySummary] = []

    for partial in partials {
      teams.append(contentsOf: partial.teams)
      competitions.append(contentsOf: partial.competitions)
      venues.append(contentsOf: partial.venues)
      schedules.append(contentsOf: partial.schedules)
      history.append(contentsOf: partial.history)
      acknowledged.formUnion(partial.acknowledgedChangeIds)
      if let synced = partial.lastSyncedAt {
        if let current = lastSyncedAt {
          if synced > current {
            lastSyncedAt = synced
          }
        } else {
          lastSyncedAt = synced
        }
      }
      if let partialSettings = partial.settings {
        settings = partialSettings
      }
    }

    return AggregateSnapshotPayload(
      schemaVersion: AggregateSyncSchema.currentVersion,
      generatedAt: first.generatedAt,
      lastSyncedAt: lastSyncedAt,
      acknowledgedChangeIds: Array(acknowledged),
      chunk: nil,
      settings: settings,
      teams: teams,
      venues: venues,
      competitions: competitions,
      schedules: schedules,
      history: history)
  }

  private func mutateStatus(_ update: (AggregateSyncStatusRecord) -> Void) {
    self.libraryStore.updateStatus(update)
    self.notifyStatusChange()
  }

  private func shouldProcess(payload: AggregateSnapshotPayload) -> Bool {
    let status = self.libraryStore.loadOrCreateStatus()
    guard let lastGenerated = status.lastSnapshotGeneratedAt else {
      return true
    }
    if payload.generatedAt < lastGenerated {
      self.log
        .notice(
          "Dropping stale snapshot payload " +
            "generatedAt=\(payload.generatedAt as NSDate, privacy: .public) " +
            "lastGenerated=\(lastGenerated as NSDate, privacy: .public)")
      return false
    }
    if payload.generatedAt == lastGenerated, status.pendingSnapshotChunks == 0 {
      self.log
        .notice(
          "Dropping duplicate snapshot payload for generatedAt=\(payload.generatedAt as NSDate, privacy: .public)")
      return false
    }
    return true
  }

  private func updateQueuedDeltaCount() {
    do {
      let pending = try deltaStore.pendingDeltas().count
      self.mutateStatus { status in
        status.queuedDeltas = pending
      }
    } catch {
      self.log.error("Failed to refresh delta queue count: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func notifyStatusChange() {
    let status = self.libraryStore.loadOrCreateStatus()
    self.statusDidChange?(status)
    NotificationCenter.default.post(
      name: .syncStatusUpdate,
      object: nil,
      userInfo: [
        "component": "aggregateSync",
        "pendingPushes": status.queuedSnapshots,
        "pendingDeletions": status.queuedDeltas,
        "signedIn": true,
        "timestamp": Date(),
        "pendingSnapshotChunks": status.pendingSnapshotChunks,
        "reachable": status.reachable,
      ])
  }
}
