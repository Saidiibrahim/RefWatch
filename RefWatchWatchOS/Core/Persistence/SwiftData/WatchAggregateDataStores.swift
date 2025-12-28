//
//  WatchAggregateDataStores.swift
//  RefWatchWatchOS
//
//  SwiftData-backed stores for aggregate library data and delta outbox queues.
//

import Foundation
import SwiftData
import RefWatchCore

@MainActor
final class WatchAggregateLibraryStore {
  private let container: ModelContainer
  let context: ModelContext

  init(container: ModelContainer) {
    self.container = container
    self.context = ModelContext(container)
  }

  func fetchTeams() throws -> [AggregateTeamRecord] {
    let descriptor = FetchDescriptor<AggregateTeamRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  func fetchCompetitions() throws -> [AggregateCompetitionRecord] {
    let descriptor = FetchDescriptor<AggregateCompetitionRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  func fetchVenues() throws -> [AggregateVenueRecord] {
    let descriptor = FetchDescriptor<AggregateVenueRecord>(
      sortBy: [SortDescriptor(\.name, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  func fetchSchedules() throws -> [AggregateScheduleRecord] {
    let descriptor = FetchDescriptor<AggregateScheduleRecord>(
      sortBy: [SortDescriptor(\.kickoff, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  func fetchInboundHistory(limit: Int = 100, cutoffDays: Int = 90) throws -> [AggregateHistoryRecord] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -cutoffDays, to: Date()) ?? Date.distantPast
    let predicate = #Predicate<AggregateHistoryRecord> { $0.completedAt >= cutoff }
    var descriptor = FetchDescriptor<AggregateHistoryRecord>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
    )
    descriptor.fetchLimit = max(1, limit)
    return try context.fetch(descriptor)
  }

  func replaceLibrary(with payload: AggregateSnapshotPayload) throws {
    try truncateLibrary()

    for team in payload.teams {
      let record = AggregateTeamRecord(
        id: team.id,
        ownerSupabaseId: team.ownerSupabaseId,
        lastModifiedAt: team.lastModifiedAt,
        remoteUpdatedAt: team.remoteUpdatedAt,
        name: team.name,
        shortName: team.shortName,
        division: team.division,
        primaryColorHex: team.primaryColorHex,
        secondaryColorHex: team.secondaryColorHex,
        needsRemoteSync: false
      )
      context.insert(record)

      for player in team.players {
        let playerRecord = AggregatePlayerRecord(
          id: player.id,
          name: player.name,
          number: player.number,
          position: player.position,
          notes: player.notes,
          team: record
        )
        record.players.append(playerRecord)
        context.insert(playerRecord)
      }

      for official in team.officials {
        let officialRecord = AggregateTeamOfficialRecord(
          id: official.id,
          name: official.name,
          roleRaw: official.roleRaw,
          phone: official.phone,
          email: official.email,
          team: record
        )
        record.officials.append(officialRecord)
        context.insert(officialRecord)
      }
    }

    for competition in payload.competitions {
      let record = AggregateCompetitionRecord(
        id: competition.id,
        ownerSupabaseId: competition.ownerSupabaseId,
        lastModifiedAt: competition.lastModifiedAt,
        remoteUpdatedAt: competition.remoteUpdatedAt,
        name: competition.name,
        level: competition.level,
        needsRemoteSync: false
      )
      context.insert(record)
    }

    for venue in payload.venues {
      let record = AggregateVenueRecord(
        id: venue.id,
        ownerSupabaseId: venue.ownerSupabaseId,
        lastModifiedAt: venue.lastModifiedAt,
        remoteUpdatedAt: venue.remoteUpdatedAt,
        name: venue.name,
        city: venue.city,
        country: venue.country,
        latitude: venue.latitude,
        longitude: venue.longitude,
        needsRemoteSync: false
      )
      context.insert(record)
    }

    for schedule in payload.schedules {
      let record = AggregateScheduleRecord(
        id: schedule.id,
        ownerSupabaseId: schedule.ownerSupabaseId,
        lastModifiedAt: schedule.lastModifiedAt,
        remoteUpdatedAt: schedule.remoteUpdatedAt,
        homeName: schedule.homeName,
        awayName: schedule.awayName,
        kickoff: schedule.kickoff,
        competition: schedule.competition,
        notes: schedule.notes,
        statusRaw: schedule.statusRaw,
        sourceDeviceId: schedule.sourceDeviceId,
        needsRemoteSync: false
      )
      context.insert(record)
    }

    // Upsert inbound history summaries
    // Keep bounded by trimming older entries beyond 100 if needed
    let summaries = payload.history
    if summaries.isEmpty == false {
      // Simple upsert by id
      for item in summaries {
        if let existing = try? fetchHistoryRecord(id: item.id) {
          existing.completedAt = item.completedAt
          existing.homeName = item.homeName
          existing.awayName = item.awayName
          existing.homeScore = item.homeScore
          existing.awayScore = item.awayScore
          existing.competitionName = item.competitionName
          existing.venueName = item.venueName
        } else {
          let rec = AggregateHistoryRecord(
            id: item.id,
            completedAt: item.completedAt,
            homeName: item.homeName,
            awayName: item.awayName,
            homeScore: item.homeScore,
            awayScore: item.awayScore,
            competitionName: item.competitionName,
            venueName: item.venueName
          )
          context.insert(rec)
        }
      }

      // Trim to 100 newest
      let all = try fetchInboundHistory(limit: Int.max, cutoffDays: 3650)
      if all.count > 100 {
        let toDelete = Array(all.suffix(from: 100))
        toDelete.forEach { context.delete($0) }
      }
    }

    if context.hasChanges {
      try context.save()
    }
  }

  func loadOrCreateStatus() -> AggregateSyncStatusRecord {
    if let existing = try? context.fetch(FetchDescriptor<AggregateSyncStatusRecord>()).first {
      return existing
    }
    let record = AggregateSyncStatusRecord()
    context.insert(record)
    try? context.save()
    return record
  }

  func updateStatus(_ update: (AggregateSyncStatusRecord) -> Void) {
    let status = loadOrCreateStatus()
    update(status)
    do {
      try context.save()
    } catch {
      // Swallow for now; diagnostics will log elsewhere during pipeline work.
    }
  }

  func wipeAll() throws {
    try truncateLibrary()
    try deleteAll(of: AggregateSnapshotChunkRecord.self)
    try deleteAll(of: AggregateDeltaRecord.self)
    try deleteAll(of: AggregateSyncStatusRecord.self)
    if context.hasChanges {
      try context.save()
    }
  }

  private func deleteAll<T: PersistentModel>(of type: T.Type) throws {
    let descriptor = FetchDescriptor<T>()
    let objects = try context.fetch(descriptor)
    for object in objects {
      context.delete(object)
    }
  }

  private func truncateLibrary() throws {
    try deleteAll(of: AggregateTeamRecord.self)
    try deleteAll(of: AggregateCompetitionRecord.self)
    try deleteAll(of: AggregateVenueRecord.self)
    try deleteAll(of: AggregateScheduleRecord.self)
    try deleteAll(of: AggregateHistoryRecord.self)
    try deleteAll(of: AggregatePlayerRecord.self)
    try deleteAll(of: AggregateTeamOfficialRecord.self)
    if context.hasChanges {
      try context.save()
    }
  }

  private func fetchHistoryRecord(id: UUID) throws -> AggregateHistoryRecord? {
    let predicate = #Predicate<AggregateHistoryRecord> { $0.id == id }
    var descriptor = FetchDescriptor<AggregateHistoryRecord>(predicate: predicate)
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }
}

@MainActor
final class WatchAggregateSnapshotChunkStore {
  private let container: ModelContainer
  let context: ModelContext

  init(container: ModelContainer) {
    self.container = container
    self.context = ModelContext(container)
  }

  func saveChunk(data: Data, payload: AggregateSnapshotPayload) throws -> [AggregateSnapshotChunkRecord] {
    guard let chunk = payload.chunk else { return [] }
    let record = AggregateSnapshotChunkRecord(
      generatedAt: payload.generatedAt,
      index: chunk.index,
      count: chunk.count,
      data: data
    )
    if let existing = try fetchChunk(generatedAt: payload.generatedAt, index: chunk.index) {
      existing.data = data
      existing.count = chunk.count
      existing.createdAt = Date()
    } else {
      context.insert(record)
    }
    try context.save()
    return try chunks(for: payload.generatedAt)
  }

  func chunks(for generatedAt: Date) throws -> [AggregateSnapshotChunkRecord] {
    let predicate = #Predicate<AggregateSnapshotChunkRecord> { $0.generatedAt == generatedAt }
    let descriptor = FetchDescriptor<AggregateSnapshotChunkRecord>(
      predicate: predicate,
      sortBy: [SortDescriptor(\.index, order: .forward)]
    )
    return try context.fetch(descriptor)
  }

  func removeChunks(for generatedAt: Date) throws {
    let records = try chunks(for: generatedAt)
    records.forEach { context.delete($0) }
    if context.hasChanges {
      try context.save()
    }
  }

  func reset() throws {
    let descriptor = FetchDescriptor<AggregateSnapshotChunkRecord>()
    let records = try context.fetch(descriptor)
    records.forEach { context.delete($0) }
    if context.hasChanges {
      try context.save()
    }
  }

  private func fetchChunk(generatedAt: Date, index: Int) throws -> AggregateSnapshotChunkRecord? {
    let key = AggregateSnapshotChunkRecord.makeKey(generatedAt: generatedAt, index: index)
    let predicate = #Predicate<AggregateSnapshotChunkRecord> { $0.key == key }
    var descriptor = FetchDescriptor<AggregateSnapshotChunkRecord>(predicate: predicate)
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }
}

@MainActor
final class WatchAggregateDeltaOutboxStore {
  private let container: ModelContainer
  let context: ModelContext

  init(container: ModelContainer) {
    self.container = container
    self.context = ModelContext(container)
  }

  func enqueue(_ envelope: AggregateDeltaEnvelope, enqueuedAt: Date = Date()) throws {
    if let existing = try fetchRecord(id: envelope.id) {
      update(existing, with: envelope, enqueuedAt: enqueuedAt)
    } else {
      let record = AggregateDeltaRecord(
        id: envelope.id,
        entityRaw: envelope.entity.rawValue,
        actionRaw: envelope.action.rawValue,
        payloadData: envelope.payload,
        modifiedAt: envelope.modifiedAt,
        originRaw: envelope.origin.rawValue,
        dependencies: envelope.dependencies,
        idempotencyKey: envelope.idempotencyKey,
        requiresSnapshotRefresh: envelope.requiresSnapshotRefresh,
        enqueuedAt: enqueuedAt
      )
      context.insert(record)
    }
    try context.save()
  }

  func pendingDeltas() throws -> [AggregateDeltaRecord] {
    let descriptor = FetchDescriptor<AggregateDeltaRecord>(
      sortBy: [
        SortDescriptor(\.enqueuedAt, order: .forward),
        SortDescriptor(\.id, order: .forward)
      ]
    )
    return try context.fetch(descriptor)
  }

  func markAttempted(ids: [UUID], at date: Date = Date()) throws {
    guard ids.isEmpty == false else { return }
    for id in ids {
      if let record = try fetchRecord(id: id) {
        record.lastAttemptAt = date
        record.failureCount += 1
      }
    }
    if context.hasChanges {
      try context.save()
    }
  }

  func markAcknowledged(ids: [UUID]) throws {
    guard ids.isEmpty == false else { return }
    for id in ids {
      if let record = try fetchRecord(id: id) {
        context.delete(record)
      }
    }
    if context.hasChanges {
      try context.save()
    }
  }

  func removeAll() throws {
    let descriptor = FetchDescriptor<AggregateDeltaRecord>()
    let records = try context.fetch(descriptor)
    records.forEach { context.delete($0) }
    if context.hasChanges {
      try context.save()
    }
  }

  private func fetchRecord(id: UUID) throws -> AggregateDeltaRecord? {
    let predicate = #Predicate<AggregateDeltaRecord> { $0.id == id }
    var descriptor = FetchDescriptor<AggregateDeltaRecord>(predicate: predicate)
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  private func update(_ record: AggregateDeltaRecord, with envelope: AggregateDeltaEnvelope, enqueuedAt: Date) {
    record.entityRaw = envelope.entity.rawValue
    record.actionRaw = envelope.action.rawValue
    record.payloadData = envelope.payload
    record.modifiedAt = envelope.modifiedAt
    record.originRaw = envelope.origin.rawValue
    record.dependencies = envelope.dependencies
    record.idempotencyKey = envelope.idempotencyKey
    record.requiresSnapshotRefresh = envelope.requiresSnapshotRefresh
    record.enqueuedAt = enqueuedAt
  }
}
