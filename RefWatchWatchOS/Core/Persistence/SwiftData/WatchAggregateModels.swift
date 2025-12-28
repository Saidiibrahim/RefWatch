//
//  WatchAggregateModels.swift
//  RefWatchWatchOS
//
//  SwiftData models backing aggregate sync payloads on watchOS.
//

import Foundation
import SwiftData

@Model
final class AggregateTeamRecord {
  @Attribute(.unique) var id: UUID
  var ownerSupabaseId: String?
  var lastModifiedAt: Date
  var remoteUpdatedAt: Date?
  var name: String
  var shortName: String?
  var division: String?
  var primaryColorHex: String?
  var secondaryColorHex: String?
  var needsRemoteSync: Bool

  @Relationship(deleteRule: .cascade, inverse: \AggregatePlayerRecord.team)
  var players: [AggregatePlayerRecord]

  @Relationship(deleteRule: .cascade, inverse: \AggregateTeamOfficialRecord.team)
  var officials: [AggregateTeamOfficialRecord]

  init(
    id: UUID = UUID(),
    ownerSupabaseId: String? = nil,
    lastModifiedAt: Date = Date(),
    remoteUpdatedAt: Date? = nil,
    name: String,
    shortName: String? = nil,
    division: String? = nil,
    primaryColorHex: String? = nil,
    secondaryColorHex: String? = nil,
    needsRemoteSync: Bool = false
  ) {
    self.id = id
    self.ownerSupabaseId = ownerSupabaseId
    self.lastModifiedAt = lastModifiedAt
    self.remoteUpdatedAt = remoteUpdatedAt
    self.name = name
    self.shortName = shortName
    self.division = division
    self.primaryColorHex = primaryColorHex
    self.secondaryColorHex = secondaryColorHex
    self.needsRemoteSync = needsRemoteSync
    self.players = []
    self.officials = []
  }
}

@Model
final class AggregatePlayerRecord {
  @Attribute(.unique) var id: UUID
  var name: String
  var number: Int?
  var position: String?
  var notes: String?
  var team: AggregateTeamRecord?

  init(
    id: UUID = UUID(),
    name: String,
    number: Int? = nil,
    position: String? = nil,
    notes: String? = nil,
    team: AggregateTeamRecord? = nil
  ) {
    self.id = id
    self.name = name
    self.number = number
    self.position = position
    self.notes = notes
    self.team = team
  }
}

@Model
final class AggregateTeamOfficialRecord {
  @Attribute(.unique) var id: UUID
  var name: String
  var roleRaw: String
  var phone: String?
  var email: String?
  var team: AggregateTeamRecord?

  init(
    id: UUID = UUID(),
    name: String,
    roleRaw: String,
    phone: String? = nil,
    email: String? = nil,
    team: AggregateTeamRecord? = nil
  ) {
    self.id = id
    self.name = name
    self.roleRaw = roleRaw
    self.phone = phone
    self.email = email
    self.team = team
  }
}

@Model
final class AggregateCompetitionRecord {
  @Attribute(.unique) var id: UUID
  var ownerSupabaseId: String?
  var lastModifiedAt: Date
  var remoteUpdatedAt: Date?
  var name: String
  var level: String?
  var needsRemoteSync: Bool

  init(
    id: UUID = UUID(),
    ownerSupabaseId: String? = nil,
    lastModifiedAt: Date = Date(),
    remoteUpdatedAt: Date? = nil,
    name: String,
    level: String? = nil,
    needsRemoteSync: Bool = false
  ) {
    self.id = id
    self.ownerSupabaseId = ownerSupabaseId
    self.lastModifiedAt = lastModifiedAt
    self.remoteUpdatedAt = remoteUpdatedAt
    self.name = name
    self.level = level
    self.needsRemoteSync = needsRemoteSync
  }
}

@Model
final class AggregateVenueRecord {
  @Attribute(.unique) var id: UUID
  var ownerSupabaseId: String?
  var lastModifiedAt: Date
  var remoteUpdatedAt: Date?
  var name: String
  var city: String?
  var country: String?
  var latitude: Double?
  var longitude: Double?
  var needsRemoteSync: Bool

  init(
    id: UUID = UUID(),
    ownerSupabaseId: String? = nil,
    lastModifiedAt: Date = Date(),
    remoteUpdatedAt: Date? = nil,
    name: String,
    city: String? = nil,
    country: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    needsRemoteSync: Bool = false
  ) {
    self.id = id
    self.ownerSupabaseId = ownerSupabaseId
    self.lastModifiedAt = lastModifiedAt
    self.remoteUpdatedAt = remoteUpdatedAt
    self.name = name
    self.city = city
    self.country = country
    self.latitude = latitude
    self.longitude = longitude
    self.needsRemoteSync = needsRemoteSync
  }
}

@Model
final class AggregateScheduleRecord {
  @Attribute(.unique) var id: UUID
  var ownerSupabaseId: String?
  var lastModifiedAt: Date
  var remoteUpdatedAt: Date?
  var homeName: String
  var awayName: String
  var kickoff: Date
  var competition: String?
  var notes: String?
  var statusRaw: String
  var sourceDeviceId: String?
  var needsRemoteSync: Bool

  init(
    id: UUID = UUID(),
    ownerSupabaseId: String? = nil,
    lastModifiedAt: Date = Date(),
    remoteUpdatedAt: Date? = nil,
    homeName: String,
    awayName: String,
    kickoff: Date,
    competition: String? = nil,
    notes: String? = nil,
    statusRaw: String,
    sourceDeviceId: String? = nil,
    needsRemoteSync: Bool = false
  ) {
    self.id = id
    self.ownerSupabaseId = ownerSupabaseId
    self.lastModifiedAt = lastModifiedAt
    self.remoteUpdatedAt = remoteUpdatedAt
    self.homeName = homeName
    self.awayName = awayName
    self.kickoff = kickoff
    self.competition = competition
    self.notes = notes
    self.statusRaw = statusRaw
    self.sourceDeviceId = sourceDeviceId
    self.needsRemoteSync = needsRemoteSync
  }
}

@Model
final class AggregateHistoryRecord {
  @Attribute(.unique) var id: UUID
  var completedAt: Date
  var homeName: String
  var awayName: String
  var homeScore: Int
  var awayScore: Int
  var competitionName: String?
  var venueName: String?

  init(
    id: UUID = UUID(),
    completedAt: Date,
    homeName: String,
    awayName: String,
    homeScore: Int,
    awayScore: Int,
    competitionName: String? = nil,
    venueName: String? = nil
  ) {
    self.id = id
    self.completedAt = completedAt
    self.homeName = homeName
    self.awayName = awayName
    self.homeScore = homeScore
    self.awayScore = awayScore
    self.competitionName = competitionName
    self.venueName = venueName
  }
}

@Model
final class AggregateSnapshotChunkRecord {
  @Attribute(.unique) var key: String
  var generatedAt: Date
  var index: Int
  var count: Int
  var data: Data
  var createdAt: Date

  init(
    generatedAt: Date,
    index: Int,
    count: Int,
    data: Data,
    createdAt: Date = Date()
  ) {
    self.key = AggregateSnapshotChunkRecord.makeKey(generatedAt: generatedAt, index: index)
    self.generatedAt = generatedAt
    self.index = index
    self.count = count
    self.data = data
    self.createdAt = createdAt
  }

  static func makeKey(generatedAt: Date, index: Int) -> String {
    let base = String(format: "%.6f", generatedAt.timeIntervalSinceReferenceDate)
    return "\(base)-\(index)"
  }
}

@Model
final class AggregateDeltaRecord {
  @Attribute(.unique) var id: UUID
  var entityRaw: String
  var actionRaw: String
  var payloadData: Data?
  var modifiedAt: Date
  var originRaw: String
  var dependencies: [UUID]
  var idempotencyKey: UUID
  var requiresSnapshotRefresh: Bool
  var enqueuedAt: Date
  var lastAttemptAt: Date?
  var failureCount: Int

  init(
    id: UUID = UUID(),
    entityRaw: String,
    actionRaw: String,
    payloadData: Data?,
    modifiedAt: Date,
    originRaw: String,
    dependencies: [UUID] = [],
    idempotencyKey: UUID? = nil,
    requiresSnapshotRefresh: Bool = false,
    enqueuedAt: Date = Date(),
    lastAttemptAt: Date? = nil,
    failureCount: Int = 0
  ) {
    self.id = id
    self.entityRaw = entityRaw
    self.actionRaw = actionRaw
    self.payloadData = payloadData
    self.modifiedAt = modifiedAt
    self.originRaw = originRaw
    self.dependencies = dependencies
    self.idempotencyKey = idempotencyKey ?? id
    self.requiresSnapshotRefresh = requiresSnapshotRefresh
    self.enqueuedAt = enqueuedAt
    self.lastAttemptAt = lastAttemptAt
    self.failureCount = failureCount
  }
}

@Model
final class AggregateSyncStatusRecord {
  @Attribute(.unique) var id: String
  var lastSnapshotGeneratedAt: Date?
  var lastSnapshotAppliedAt: Date?
  var pendingSnapshotChunks: Int
  var queuedSnapshots: Int
  var queuedDeltas: Int
  var reachable: Bool
  var lastConnectivityStatusRaw: String?
  var lastSupabaseSync: Date?
  var requiresBackfill: Bool

  init(
    id: String = "aggregate-sync-status",
    lastSnapshotGeneratedAt: Date? = nil,
    lastSnapshotAppliedAt: Date? = nil,
    pendingSnapshotChunks: Int = 0,
    queuedSnapshots: Int = 0,
    queuedDeltas: Int = 0,
    reachable: Bool = false,
    lastConnectivityStatusRaw: String? = nil,
    lastSupabaseSync: Date? = nil,
    requiresBackfill: Bool = false
  ) {
    self.id = id
    self.lastSnapshotGeneratedAt = lastSnapshotGeneratedAt
    self.lastSnapshotAppliedAt = lastSnapshotAppliedAt
    self.pendingSnapshotChunks = pendingSnapshotChunks
    self.queuedSnapshots = queuedSnapshots
    self.queuedDeltas = queuedDeltas
    self.reachable = reachable
    self.lastConnectivityStatusRaw = lastConnectivityStatusRaw
    self.lastSupabaseSync = lastSupabaseSync
    self.requiresBackfill = requiresBackfill
  }
}
