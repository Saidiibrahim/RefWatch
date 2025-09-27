//
//  SupabaseMatchIngestService.swift
//  RefZoneiOS
//
//  Handles uploading completed match bundles (match + periods + events) to
//  Supabase and fetching recent bundles for reconciliation.
//

import Foundation
import RefWatchCore
import Supabase

protocol SupabaseMatchIngestServing {
  func ingestMatchBundle(_ request: SupabaseMatchIngestService.MatchBundleRequest) async throws -> SupabaseMatchIngestService.SyncResult
  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseMatchIngestService.RemoteMatchBundle]
  func deleteMatch(id: UUID) async throws
}

struct SupabaseMatchIngestService: SupabaseMatchIngestServing {
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

    let match: MatchPayload
    let periods: [PeriodPayload]
    let events: [EventPayload]
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
  }

  enum APIError: Error, Equatable {
    case unsupportedClient
    case invalidResponse
  }

  private let clientProvider: SupabaseClientProviding
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let isoFormatter: ISO8601DateFormatter

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    encoder: JSONEncoder = SupabaseMatchIngestService.makeEncoder(),
    decoder: JSONDecoder = SupabaseMatchIngestService.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseMatchIngestService.makeISOFormatter()
  ) {
    self.clientProvider = clientProvider
    self.encoder = encoder
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func ingestMatchBundle(_ request: MatchBundleRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    let payload = try encoder.encode(request)
    let options = FunctionInvokeOptions(
      method: .post,
      headers: [
        "Content-Type": "application/json"
      ],
      body: payload
    )

    return try await supabaseClient.functionsClient.invoke(
      "matches-ingest",
      options: options,
      decoder: decoder
    )
  }

  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteMatchBundle] {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    let matches: [MatchRowDTO] = try await supabaseClient.fetchRows(
      from: "matches",
      select: "id, owner_id, status, started_at, completed_at, duration_seconds, number_of_periods, regulation_minutes, half_time_minutes, competition_id, competition_name, venue_id, venue_name, home_team_id, home_team_name, away_team_id, away_team_name, extra_time_enabled, extra_time_half_minutes, penalties_enabled, penalty_initial_rounds, home_score, away_score, final_score, source_device_id, updated_at",
      filters: makeMatchFilters(ownerId: ownerId, updatedAfter: updatedAfter),
      orderBy: "updated_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    guard matches.isEmpty == false else { return [] }

    let matchIds = matches.map { $0.id.uuidString }
    let periods: [PeriodRowDTO] = try await supabaseClient.fetchRows(
      from: "match_periods",
      select: "id, match_id, index, regulation_seconds, added_time_seconds, result",
      filters: [.in("match_id", values: matchIds)],
      orderBy: nil,
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    let events: [EventRowDTO] = try await supabaseClient.fetchRows(
      from: "match_events",
      select: "id, match_id, occurred_at, period_index, clock_seconds, match_time_label, event_type, payload, team_side",
      filters: [.in("match_id", values: matchIds)],
      orderBy: "occurred_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    let periodsByMatch = Dictionary(grouping: periods, by: { $0.matchId })
    let eventsByMatch = Dictionary(grouping: events, by: { $0.matchId })

    return matches.map { row in
      let remoteMatch = row.toRemoteMatch()
      let remotePeriods = (periodsByMatch[row.id] ?? []).map { $0.toRemotePeriod() }
      let remoteEvents = (eventsByMatch[row.id] ?? []).map { $0.toRemoteEvent() }
      return RemoteMatchBundle(match: remoteMatch, periods: remotePeriods, events: remoteEvents)
    }
  }

  func deleteMatch(id: UUID) async throws {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    _ = try await supabaseClient
      .from("matches")
      .delete()
      .eq("id", value: id.uuidString)
      .execute()
  }
}

private extension SupabaseMatchIngestService {
  static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func makeISOFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }

  func makeMatchFilters(ownerId: UUID, updatedAfter: Date?) -> [SupabaseQueryFilter] {
    var filters: [SupabaseQueryFilter] = [
      .equals("owner_id", value: ownerId.uuidString)
    ]
    if let updatedAfter {
      filters.append(.greaterThan("updated_at", value: isoFormatter.string(from: updatedAfter)))
    }
    return filters
  }
}

// MARK: - DTOs

private struct MatchRowDTO: Decodable {
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
  let finalScore: SupabaseMatchIngestService.MatchBundleRequest.FinalScorePayload?
  let sourceDeviceId: String?
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case status
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
    case updatedAt = "updated_at"
  }

  func toRemoteMatch() -> SupabaseMatchIngestService.RemoteMatch {
    SupabaseMatchIngestService.RemoteMatch(
      id: id,
      ownerId: ownerId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      durationSeconds: durationSeconds,
      numberOfPeriods: numberOfPeriods,
      regulationMinutes: regulationMinutes,
      halfTimeMinutes: halfTimeMinutes,
      competitionId: competitionId,
      competitionName: competitionName,
      venueId: venueId,
      venueName: venueName,
      homeTeamId: homeTeamId,
      homeTeamName: homeTeamName,
      awayTeamId: awayTeamId,
      awayTeamName: awayTeamName,
      extraTimeEnabled: extraTimeEnabled,
      extraTimeHalfMinutes: extraTimeHalfMinutes,
      penaltiesEnabled: penaltiesEnabled,
      penaltyInitialRounds: penaltyInitialRounds,
      homeScore: homeScore,
      awayScore: awayScore,
      finalScore: finalScore,
      sourceDeviceId: sourceDeviceId,
      updatedAt: updatedAt
    )
  }
}

private struct PeriodRowDTO: Decodable {
  let id: UUID
  let matchId: UUID
  let index: Int
  let regulationSeconds: Int
  let addedTimeSeconds: Int
  let result: SupabaseMatchIngestService.MatchBundleRequest.PeriodResultPayload?

  enum CodingKeys: String, CodingKey {
    case id
    case matchId = "match_id"
    case index
    case regulationSeconds = "regulation_seconds"
    case addedTimeSeconds = "added_time_seconds"
    case result
  }

  func toRemotePeriod() -> SupabaseMatchIngestService.RemotePeriod {
    SupabaseMatchIngestService.RemotePeriod(
      id: id,
      matchId: matchId,
      index: index,
      regulationSeconds: regulationSeconds,
      addedTimeSeconds: addedTimeSeconds,
      result: result
    )
  }
}

private struct EventRowDTO: Decodable {
  let id: UUID
  let matchId: UUID
  let occurredAt: Date
  let periodIndex: Int
  let clockSeconds: Int
  let matchTimeLabel: String
  let eventType: String
  let payload: MatchEventRecord?
  let teamSide: String?

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
  }

  func toRemoteEvent() -> SupabaseMatchIngestService.RemoteEvent {
    SupabaseMatchIngestService.RemoteEvent(
      id: id,
      matchId: matchId,
      occurredAt: occurredAt,
      periodIndex: periodIndex,
      clockSeconds: clockSeconds,
      matchTimeLabel: matchTimeLabel,
      eventType: eventType,
      payload: payload,
      teamSide: teamSide
    )
  }
}
