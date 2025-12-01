//
//  WatchAggregateModelSchema.swift
//  RefZoneWatchOS
//
//  Centralised schema definition for aggregate SwiftData models.
//

import SwiftData

enum WatchAggregateModelSchema {
  static let schema = Schema([
    AggregateTeamRecord.self,
    AggregatePlayerRecord.self,
    AggregateTeamOfficialRecord.self,
    AggregateCompetitionRecord.self,
    AggregateVenueRecord.self,
    AggregateScheduleRecord.self,
    AggregateHistoryRecord.self,
    AggregateSnapshotChunkRecord.self,
    AggregateDeltaRecord.self,
    AggregateSyncStatusRecord.self
  ])
}
