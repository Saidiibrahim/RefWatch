//
//  MatchRemoteContract.swift
//  RefWatchiOS
//
//  Handles uploading completed match bundles (match + periods + events) to
//  Supabase and fetching recent bundles for reconciliation.
//

import Foundation
import RefWatchCore
internal import os

protocol MatchRemoteServing {
  func ingestMatchBundle(_ request: MatchRemoteContract.MatchBundleRequest) async throws
    -> MatchRemoteContract.SyncResult
  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws
    -> [MatchRemoteContract.RemoteMatchBundle]
  func deleteMatch(id: UUID) async throws
}

struct MatchRemoteContract {
  struct MatchBundleRequest: Encodable, Equatable {
    struct MatchPayload: Encodable, Equatable {
      let id: UUID
      let ownerId: UUID
      let status: String
      let scheduledMatchId: UUID?
      let startedAt: Date?
      let completedAt: Date
      let durationSeconds: Int
      let numberOfPeriods: Int
      let regulationMinutes: Int?
      let halfTimeMinutes: Int?
      let competitionId: UUID?
      let competitionName: String?
      let venueId: UUID?
      let venueName: String?
      let homeTeamId: UUID?
      let homeTeamName: String
      let awayTeamId: UUID?
      let awayTeamName: String
      let extraTimeEnabled: Bool
      let extraTimeHalfMinutes: Int?
      let penaltiesEnabled: Bool
      let penaltyInitialRounds: Int
      let homeScore: Int
      let awayScore: Int
      let finalScore: FinalScorePayload?
      let sourceDeviceId: String?

      enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case status
        case scheduledMatchId = "scheduled_match_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationSeconds = "duration_seconds"
        case numberOfPeriods = "number_of_periods"
        case regulationMinutes = "regulation_minutes"
        case halfTimeMinutes = "half_time_minutes"
        case competitionId = "competition_id"
        case competitionName = "competition_name"
        case venueId = "venue_id"
        case venueName = "venue_name"
        case homeTeamId = "home_team_id"
        case homeTeamName = "home_team_name"
        case awayTeamId = "away_team_id"
        case awayTeamName = "away_team_name"
        case extraTimeEnabled = "extra_time_enabled"
        case extraTimeHalfMinutes = "extra_time_half_minutes"
        case penaltiesEnabled = "penalties_enabled"
        case penaltyInitialRounds = "penalty_initial_rounds"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case finalScore = "final_score"
        case sourceDeviceId = "source_device_id"
      }
    }

    struct PeriodPayload: Encodable, Equatable {
      let id: UUID
      let matchId: UUID
      let index: Int
      let regulationSeconds: Int
      let addedTimeSeconds: Int
      let result: PeriodResultPayload?

      enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case index
        case regulationSeconds = "regulation_seconds"
        case addedTimeSeconds = "added_time_seconds"
        case result
      }
    }

    struct EventPayload: Encodable, Equatable {
      let id: UUID
      let matchId: UUID
      let occurredAt: Date
      let periodIndex: Int
      let clockSeconds: Int
      let matchTimeLabel: String
      let eventType: String
      let payload: MatchEventRecord
      let teamSide: String?
      let teamId: UUID?
      let teamMemberId: UUID?

      enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case occurredAt = "occurred_at"
        case periodIndex = "period_index"
        case clockSeconds = "clock_seconds"
        case matchTimeLabel = "match_time_label"
        case eventType = "event_type"
        case payload
        case teamSide = "team_side"
        case teamId = "team_id"
        case teamMemberId = "team_member_id"
      }
    }

    struct FinalScorePayload: Codable, Equatable {
      let home: Int
      let away: Int
      let homeYellowCards: Int
      let awayYellowCards: Int
      let homeRedCards: Int
      let awayRedCards: Int
      let homeSubstitutions: Int
      let awaySubstitutions: Int

      enum CodingKeys: String, CodingKey {
        case home
        case away
        case homeYellowCards = "home_yellow_cards"
        case awayYellowCards = "away_yellow_cards"
        case homeRedCards = "home_red_cards"
        case awayRedCards = "away_red_cards"
        case homeSubstitutions = "home_substitutions"
        case awaySubstitutions = "away_substitutions"
      }
    }

    struct PeriodResultPayload: Codable, Equatable {
      let homeScore: Int
      let awayScore: Int

      enum CodingKeys: String, CodingKey {
        case homeScore = "home_score"
        case awayScore = "away_score"
      }
    }

    struct MetricsPayload: Encodable, Equatable {
      let matchId: UUID
      let ownerId: UUID
      let regulationMinutes: Int?
      let halfTimeMinutes: Int?
      let extraTimeMinutes: Int?
      let penaltiesEnabled: Bool
      let totalGoals: Int
      let totalCards: Int
      let totalPenalties: Int
      let yellowCards: Int
      let redCards: Int
      let homeCards: Int
      let awayCards: Int
      let homeSubstitutions: Int
      let awaySubstitutions: Int
      let penaltiesScored: Int
      let penaltiesMissed: Int
      let avgAddedTimeSeconds: Int

      enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case ownerId = "owner_id"
        case regulationMinutes = "regulation_minutes"
        case halfTimeMinutes = "half_time_minutes"
        case extraTimeMinutes = "extra_time_minutes"
        case penaltiesEnabled = "penalties_enabled"
        case totalGoals = "total_goals"
        case totalCards = "total_cards"
        case totalPenalties = "total_penalties"
        case yellowCards = "yellow_cards"
        case redCards = "red_cards"
        case homeCards = "home_cards"
        case awayCards = "away_cards"
        case homeSubstitutions = "home_substitutions"
        case awaySubstitutions = "away_substitutions"
        case penaltiesScored = "penalties_scored"
        case penaltiesMissed = "penalties_missed"
        case avgAddedTimeSeconds = "avg_added_time_seconds"
      }
    }

    let match: MatchPayload
    let periods: [PeriodPayload]
    let events: [EventPayload]
    let metrics: MetricsPayload?
  }

  struct SyncResult: Decodable, Equatable {
    let matchId: UUID
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
      case matchId = "match_id"
      case updatedAt = "updated_at"
    }
  }

  struct RemoteMatchBundle: Equatable {
    let match: RemoteMatch
    let periods: [RemotePeriod]
    let events: [RemoteEvent]
    let metrics: RemoteMetrics?
  }

  struct RemoteMatch: Equatable {
    let id: UUID
    let ownerId: UUID
    let status: String
    let startedAt: Date?
    let completedAt: Date
    let durationSeconds: Int?
    let numberOfPeriods: Int
    let regulationMinutes: Int?
    let halfTimeMinutes: Int?
    let competitionId: UUID?
    let competitionName: String?
    let venueId: UUID?
    let venueName: String?
    let homeTeamId: UUID?
    let homeTeamName: String
    let awayTeamId: UUID?
    let awayTeamName: String
    let extraTimeEnabled: Bool
    let extraTimeHalfMinutes: Int?
    let penaltiesEnabled: Bool
    let penaltyInitialRounds: Int
    let homeScore: Int
    let awayScore: Int
    let finalScore: MatchBundleRequest.FinalScorePayload?
    let sourceDeviceId: String?
    let updatedAt: Date
    var deletedAt: Date? = nil
  }

  struct RemotePeriod: Equatable {
    let id: UUID
    let matchId: UUID
    let index: Int
    let regulationSeconds: Int
    let addedTimeSeconds: Int
    let result: MatchBundleRequest.PeriodResultPayload?
  }

  struct RemoteEvent: Equatable {
    let id: UUID
    let matchId: UUID
    let occurredAt: Date
    let periodIndex: Int
    let clockSeconds: Int
    let matchTimeLabel: String
    let eventType: String
    let payload: MatchEventRecord?
    let teamSide: String?
    let teamId: UUID?
    let teamMemberId: UUID?
  }

  struct RemoteMetrics: Equatable {
    let matchId: UUID
    let ownerId: UUID
    let regulationMinutes: Int?
    let halfTimeMinutes: Int?
    let extraTimeMinutes: Int?
    let penaltiesEnabled: Bool
    let totalGoals: Int
    let totalCards: Int
    let totalPenalties: Int
    let yellowCards: Int
    let redCards: Int
    let homeCards: Int
    let awayCards: Int
    let homeSubstitutions: Int
    let awaySubstitutions: Int
    let penaltiesScored: Int
    let penaltiesMissed: Int
    let avgAddedTimeSeconds: Int
    let generatedAt: Date
  }

  enum APIError: Error, Equatable {
    case unsupportedClient
    case invalidResponse
  }

}
