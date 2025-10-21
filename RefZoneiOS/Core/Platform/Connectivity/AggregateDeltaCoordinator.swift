//
//  AggregateDeltaCoordinator.swift
//  RefZoneiOS
//
//  Applies watch-authored aggregate deltas to local repositories and records
//  acknowledgement identifiers so iOS snapshots can echo them back.
//

import Foundation
import OSLog
import RefWatchCore

@MainActor
protocol AggregateDeltaHandling: AnyObject {
  func processDelta(_ envelope: AggregateDeltaEnvelope) async throws
}

@MainActor
final class AggregateDeltaCoordinator: AggregateDeltaHandling {
  private let teamRepository: AggregateTeamApplying
  private let competitionRepository: AggregateCompetitionApplying
  private let venueRepository: AggregateVenueApplying
  private let scheduleRepository: AggregateScheduleApplying
  private let ackStore: AggregateDeltaAckStoring
  private let snapshotRefreshHandler: () -> Void
  private let decoder = AggregateSyncCoding.makeDecoder()
  private let log = Logger(subsystem: "RefZoneiOS", category: "aggregateDelta")

  init(
    teamRepository: AggregateTeamApplying,
    competitionRepository: AggregateCompetitionApplying,
    venueRepository: AggregateVenueApplying,
    scheduleRepository: AggregateScheduleApplying,
    ackStore: AggregateDeltaAckStoring,
    snapshotRefreshHandler: @escaping () -> Void
  ) {
    self.teamRepository = teamRepository
    self.competitionRepository = competitionRepository
    self.venueRepository = venueRepository
    self.scheduleRepository = scheduleRepository
    self.ackStore = ackStore
    self.snapshotRefreshHandler = snapshotRefreshHandler
  }

  func processDelta(_ envelope: AggregateDeltaEnvelope) async throws {
    do {
      switch envelope.entity {
      case .team:
        try processTeamDelta(envelope)
      case .competition:
        try processCompetitionDelta(envelope)
      case .venue:
        try processVenueDelta(envelope)
      case .schedule:
        try processScheduleDelta(envelope)
      }

      ackStore.recordAck(id: envelope.id)
      if envelope.requiresSnapshotRefresh {
        snapshotRefreshHandler()
      }
    } catch {
      log.error("Failed to process aggregate delta id=\(envelope.id.uuidString, privacy: .public) entity=\(envelope.entity.rawValue, privacy: .public) action=\(envelope.action.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      NotificationCenter.default.post(
        name: .syncNonrecoverableError,
        object: nil,
        userInfo: [
          "error": error.localizedDescription,
          "context": "ios.aggregate.delta.apply",
          "entity": envelope.entity.rawValue,
          "action": envelope.action.rawValue
        ]
      )
      throw error
    }
  }
}

private extension AggregateDeltaCoordinator {
  func decodePayload<T: Decodable>(_ envelope: AggregateDeltaEnvelope, as type: T.Type) throws -> T {
    guard let data = envelope.payload else {
      throw AggregateSyncPayloadError.missingPayload
    }
    return try decoder.decode(T.self, from: data)
  }

  func processTeamDelta(_ envelope: AggregateDeltaEnvelope) throws {
    switch envelope.action {
    case .create, .update:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Team.self)
      try teamRepository.upsertTeam(from: payload)
    case .delete:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Team.self)
      try teamRepository.deleteTeam(id: payload.id)
    }
  }

  func processCompetitionDelta(_ envelope: AggregateDeltaEnvelope) throws {
    switch envelope.action {
    case .create, .update:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Competition.self)
      try competitionRepository.upsertCompetition(from: payload)
    case .delete:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Competition.self)
      try competitionRepository.deleteCompetition(id: payload.id)
    }
  }

  func processVenueDelta(_ envelope: AggregateDeltaEnvelope) throws {
    switch envelope.action {
    case .create, .update:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Venue.self)
      try venueRepository.upsertVenue(from: payload)
    case .delete:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Venue.self)
      try venueRepository.deleteVenue(id: payload.id)
    }
  }

  func processScheduleDelta(_ envelope: AggregateDeltaEnvelope) throws {
    switch envelope.action {
    case .create, .update:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Schedule.self)
      try scheduleRepository.upsertSchedule(from: payload)
    case .delete:
      let payload = try decodePayload(envelope, as: AggregateSnapshotPayload.Schedule.self)
      try scheduleRepository.deleteSchedule(id: payload.id)
    }
  }
}
