//
//  WatchAggregateSyncCoordinator.swift
//  RefZoneWatchOS
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
  private let log = Logger(subsystem: "RefZoneWatchOS", category: "aggregateSync")

  var statusDidChange: ((AggregateSyncStatusRecord) -> Void)?
  var libraryDidChange: (() -> Void)?

  init(
    libraryStore: WatchAggregateLibraryStore,
    chunkStore: WatchAggregateSnapshotChunkStore,
    deltaStore: WatchAggregateDeltaOutboxStore,
    decoder: JSONDecoder = AggregateSyncCoding.makeDecoder()
  ) {
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
      log.error("Failed to decode aggregate snapshot: \(error.localizedDescription, privacy: .public)")
    }
  }

  func enqueueDeltaEnvelope(_ envelope: AggregateDeltaEnvelope) {
    do {
      try deltaStore.enqueue(envelope)
      updateQueuedDeltaCount()
    } catch {
      log.error("Failed to enqueue delta envelope: \(error.localizedDescription, privacy: .public)")
    }
  }

  func pendingDeltaEnvelopes() -> [AggregateDeltaEnvelope] {
    do {
      return try deltaStore.pendingDeltas().compactMap { record in
        guard
          let entity = AggregateSyncEntity(rawValue: record.entityRaw),
          let action = AggregateDeltaAction(rawValue: record.actionRaw),
          let origin = AggregateSyncOrigin(rawValue: record.originRaw)
        else {
          log.error("Dropping delta with unknown metadata entity=\(record.entityRaw, privacy: .public) action=\(record.actionRaw, privacy: .public)")
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
          requiresSnapshotRefresh: record.requiresSnapshotRefresh
        )
      }
    } catch {
      log.error("Failed to load pending delta envelopes: \(error.localizedDescription, privacy: .public)")
      return []
    }
  }

  func currentStatus() -> AggregateSyncStatusRecord {
    libraryStore.loadOrCreateStatus()
  }

  func markDeltasAttempted(ids: [UUID]) {
    do {
      try deltaStore.markAttempted(ids: ids)
    } catch {
      log.error("Failed to mark delta attempt: \(error.localizedDescription, privacy: .public)")
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
      try libraryStore.wipeAll()
      try chunkStore.reset()
      try deltaStore.removeAll()
      notifyStatusChange()
      libraryDidChange?()
    } catch {
      log.error("Failed to wipe aggregate state: \(error.localizedDescription, privacy: .public)")
    }
  }
}

private extension WatchAggregateSyncCoordinator {
  func ingestSnapshotPayload(_ payload: AggregateSnapshotPayload, rawData: Data) throws {
    guard shouldProcess(payload: payload) else {
      if payload.chunk != nil {
        try? chunkStore.removeChunks(for: payload.generatedAt)
      }
      return
    }

    if let chunk = payload.chunk {
      if chunk.index == 0 {
        try chunkStore.reset()
      }
      let records = try chunkStore.saveChunk(data: rawData, payload: payload)
      let remaining = max(chunk.count - records.count, 0)
      mutateStatus { status in
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
      try applySnapshot(assembled)
    } else {
      try chunkStore.reset()
      try chunkStore.removeChunks(for: payload.generatedAt)
      try applySnapshot(payload)
    }
  }

  func applySnapshot(_ payload: AggregateSnapshotPayload) throws {
    try libraryStore.replaceLibrary(with: payload)
    let ackIds = Array(Set(payload.acknowledgedChangeIds))
    if ackIds.isEmpty == false {
      try deltaStore.markAcknowledged(ids: ackIds)
    }
    let pendingDeltaCount = (try? deltaStore.pendingDeltas().count) ?? 0
    if ackIds.isEmpty == false {
      log.debug("Acknowledged \(ackIds.count, privacy: .public) aggregate delta(s)")
    }
    mutateStatus { status in
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
    libraryDidChange?()
  }

  func assembleSnapshot(from records: [AggregateSnapshotChunkRecord]) throws -> AggregateSnapshotPayload {
    let partials = try records.sorted { $0.index < $1.index }.map { record in
      try decoder.decode(AggregateSnapshotPayload.self, from: record.data)
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
      history: history
    )
  }

  func mutateStatus(_ update: (AggregateSyncStatusRecord) -> Void) {
    libraryStore.updateStatus(update)
    notifyStatusChange()
  }

  func shouldProcess(payload: AggregateSnapshotPayload) -> Bool {
    let status = libraryStore.loadOrCreateStatus()
    guard let lastGenerated = status.lastSnapshotGeneratedAt else {
      return true
    }
    if payload.generatedAt < lastGenerated {
      log.notice("Dropping stale snapshot payload generatedAt=\(payload.generatedAt as NSDate, privacy: .public) lastGenerated=\(lastGenerated as NSDate, privacy: .public)")
      return false
    }
    if payload.generatedAt == lastGenerated, status.pendingSnapshotChunks == 0 {
      log.notice("Dropping duplicate snapshot payload for generatedAt=\(payload.generatedAt as NSDate, privacy: .public)")
      return false
    }
    return true
  }

  func updateQueuedDeltaCount() {
    do {
      let pending = try deltaStore.pendingDeltas().count
      mutateStatus { status in
        status.queuedDeltas = pending
      }
    } catch {
      log.error("Failed to refresh delta queue count: \(error.localizedDescription, privacy: .public)")
    }
  }

  func notifyStatusChange() {
    let status = libraryStore.loadOrCreateStatus()
    statusDidChange?(status)
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
        "reachable": status.reachable
      ]
    )
  }
}
