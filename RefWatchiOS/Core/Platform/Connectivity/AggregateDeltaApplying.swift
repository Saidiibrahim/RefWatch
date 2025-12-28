//
//  AggregateDeltaApplying.swift
//  RefWatchiOS
//
//  Protocols describing repository capabilities needed to merge watch-authored
//  aggregate deltas into the iOS persistence layer.
//

import Foundation
import RefWatchCore

@MainActor
protocol AggregateTeamApplying: AnyObject {
  func upsertTeam(from aggregate: AggregateSnapshotPayload.Team) throws
  func deleteTeam(id: UUID) throws
}

@MainActor
protocol AggregateCompetitionApplying: AnyObject {
  func upsertCompetition(from aggregate: AggregateSnapshotPayload.Competition) throws
  func deleteCompetition(id: UUID) throws
}

@MainActor
protocol AggregateVenueApplying: AnyObject {
  func upsertVenue(from aggregate: AggregateSnapshotPayload.Venue) throws
  func deleteVenue(id: UUID) throws
}

@MainActor
protocol AggregateScheduleApplying: AnyObject {
  func upsertSchedule(from aggregate: AggregateSnapshotPayload.Schedule) throws
  func deleteSchedule(id: UUID) throws
}
