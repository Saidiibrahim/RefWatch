//
//  AggregateSnapshotBuilder.swift
//  RefWatchiOS
//
//  Produces chunk-aware aggregate snapshots for WatchConnectivity delivery.
//

import Foundation
import OSLog
import RefWatchCore

struct AggregateSnapshotBuilder {
  private let log = AppLog.connectivity
  private let encoder: JSONEncoder
  private let maxPayloadBytes: Int

  struct SnapshotInputs {
    let teams: [TeamRecord]
    let competitions: [CompetitionRecord]
    let venues: [VenueRecord]
    let schedules: [ScheduledMatch]
    let history: [AggregateSnapshotPayload.HistorySummary]
    let acknowledgedChangeIds: [UUID]
    let generatedAt: Date
    let lastSyncedAt: Date?
    let settings: AggregateSnapshotPayload.Settings?
  }

  struct SnapshotMetadata {
    let acknowledgedChangeIds: [UUID]
    let generatedAt: Date
    let lastSyncedAt: Date?
    let settings: AggregateSnapshotPayload.Settings?
  }

  init(maxPayloadBytes: Int = 450_000) {
    self.encoder = AggregateSyncCoding.makeEncoder()
    self.maxPayloadBytes = maxPayloadBytes
  }

  func makeSnapshots(_ inputs: SnapshotInputs) -> [AggregateSnapshotPayload] {
    let metadata = SnapshotMetadata(
      acknowledgedChangeIds: inputs.acknowledgedChangeIds,
      generatedAt: inputs.generatedAt,
      lastSyncedAt: inputs.lastSyncedAt,
      settings: inputs.settings)

    let teamPayloads = inputs.teams
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      .map(makeTeamPayload)
    let competitionPayloads = inputs.competitions
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      .map(makeCompetitionPayload)
    let venuePayloads = inputs.venues
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      .map(makeVenuePayload)
    let schedulePayloads = inputs.schedules
      .sorted { $0.kickoff < $1.kickoff }
      .map(makeSchedulePayload)
    let historyPayloads = inputs.history
      .sorted { $0.completedAt > $1.completedAt }

    var chunks: [PartialSnapshot] = []
    var current = PartialSnapshot()

    func append<T>(_ item: T, to keyPath: WritableKeyPath<PartialSnapshot, [T]>) {
      var candidate = current
      candidate[keyPath: keyPath].append(item)
      let prospectiveSize = byteCount(
        for: candidate,
        chunkIndex: chunks.count,
        metadata: metadata)

      if prospectiveSize <= self.maxPayloadBytes || current.isEmpty {
        current = candidate
        return
      }

      if current.isEmpty == false {
        chunks.append(current)
        current = PartialSnapshot()
        candidate = current
        candidate[keyPath: keyPath].append(item)
        let fallbackSize = byteCount(
          for: candidate,
          chunkIndex: chunks.count,
          metadata: metadata)
        if fallbackSize > self.maxPayloadBytes {
          self.log
            .error(
              "Aggregate chunk exceeds payload limit after splitting. entity=\(String(describing: T.self), privacy: .public)")
        }
        current = candidate
      } else {
        current = candidate
        self.log
          .error(
            "Aggregate item exceeds payload limit on its own. entity=\(String(describing: T.self), privacy: .public)")
      }
    }

    teamPayloads.forEach { append($0, to: \.teams) }
    competitionPayloads.forEach { append($0, to: \.competitions) }
    venuePayloads.forEach { append($0, to: \.venues) }
    schedulePayloads.forEach { append($0, to: \.schedules) }
    historyPayloads.forEach { append($0, to: \.history) }

    if current.isEmpty == false || chunks.isEmpty {
      chunks.append(current)
    }

    let chunkCount = chunks.count

    return chunks.enumerated().map { index, partial in
      AggregateSnapshotPayload(
        generatedAt: metadata.generatedAt,
        lastSyncedAt: metadata.lastSyncedAt,
        acknowledgedChangeIds: metadata.acknowledgedChangeIds,
        chunk: chunkCount > 1 ? .init(index: index, count: chunkCount) : nil,
        settings: metadata.settings,
        teams: partial.teams,
        venues: partial.venues,
        competitions: partial.competitions,
        schedules: partial.schedules,
        history: partial.history)
    }
  }
}

extension AggregateSnapshotBuilder {
  struct PartialSnapshot {
    var teams: [AggregateSnapshotPayload.Team] = []
    var competitions: [AggregateSnapshotPayload.Competition] = []
    var venues: [AggregateSnapshotPayload.Venue] = []
    var schedules: [AggregateSnapshotPayload.Schedule] = []
    var history: [AggregateSnapshotPayload.HistorySummary] = []

    var isEmpty: Bool {
      self.teams.isEmpty && self.competitions.isEmpty && self.venues.isEmpty && self.schedules.isEmpty && self.history
        .isEmpty
    }
  }

  func byteCount(for partial: PartialSnapshot, chunkIndex: Int, metadata: SnapshotMetadata) -> Int {
    let payload = AggregateSnapshotPayload(
      generatedAt: metadata.generatedAt,
      lastSyncedAt: metadata.lastSyncedAt,
      acknowledgedChangeIds: metadata.acknowledgedChangeIds,
      chunk: chunkIndex > 0 ? .init(index: chunkIndex, count: chunkIndex + 1) : nil,
      settings: metadata.settings,
      teams: partial.teams,
      venues: partial.venues,
      competitions: partial.competitions,
      schedules: partial.schedules,
      history: partial.history)
    do {
      let data = try encoder.encode(payload)
      return data.count
    } catch {
      self.log
        .error("Failed to encode aggregate snapshot during sizing: \(error.localizedDescription, privacy: .public)")
      return Int.max
    }
  }

  func makeTeamPayload(from record: TeamRecord) -> AggregateSnapshotPayload.Team {
    let players = record.players
      .sorted { lhs, rhs in
        if let ln = lhs.number, let rn = rhs.number, ln != rn {
          return ln < rn
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      .map {
        AggregateSnapshotPayload.Team.Player(
          id: $0.id,
          name: $0.name,
          number: $0.number,
          position: $0.position,
          notes: $0.notes)
      }

    let officials = record.officials
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      .map {
        AggregateSnapshotPayload.Team.Official(
          id: $0.id,
          name: $0.name,
          roleRaw: $0.roleRaw,
          phone: $0.phone,
          email: $0.email)
      }

    return AggregateSnapshotPayload.Team(
      id: record.id,
      ownerSupabaseId: record.ownerSupabaseId,
      lastModifiedAt: record.lastModifiedAt,
      remoteUpdatedAt: record.remoteUpdatedAt,
      name: record.name,
      shortName: record.shortName,
      division: record.division,
      primaryColorHex: record.primaryColorHex,
      secondaryColorHex: record.secondaryColorHex,
      players: players,
      officials: officials)
  }

  func makeCompetitionPayload(from record: CompetitionRecord) -> AggregateSnapshotPayload.Competition {
    AggregateSnapshotPayload.Competition(
      id: record.id,
      ownerSupabaseId: record.ownerSupabaseId,
      lastModifiedAt: record.lastModifiedAt,
      remoteUpdatedAt: record.remoteUpdatedAt,
      name: record.name,
      level: record.level)
  }

  func makeVenuePayload(from record: VenueRecord) -> AggregateSnapshotPayload.Venue {
    AggregateSnapshotPayload.Venue(
      id: record.id,
      ownerSupabaseId: record.ownerSupabaseId,
      lastModifiedAt: record.lastModifiedAt,
      remoteUpdatedAt: record.remoteUpdatedAt,
      name: record.name,
      city: record.city,
      country: record.country,
      latitude: record.latitude,
      longitude: record.longitude)
  }

  func makeSchedulePayload(from match: ScheduledMatch) -> AggregateSnapshotPayload.Schedule {
    AggregateSnapshotPayload.Schedule(
      id: match.id,
      ownerSupabaseId: match.ownerSupabaseId,
      lastModifiedAt: match.lastModifiedAt ?? match.remoteUpdatedAt ?? match.kickoff,
      remoteUpdatedAt: match.remoteUpdatedAt,
      homeName: match.homeTeam,
      awayName: match.awayTeam,
      kickoff: match.kickoff,
      competition: match.competition,
      notes: match.notes,
      statusRaw: match.status.databaseValue,
      sourceDeviceId: match.sourceDeviceId)
  }
}
