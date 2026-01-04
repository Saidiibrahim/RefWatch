//
//  SupabaseMatchIngestService.swift
//  RefWatchiOS
//
//  Handles uploading completed match bundles (match + periods + events) to
//  Supabase and fetching recent bundles for reconciliation.
//

import Foundation
import RefWatchCore
import Supabase
internal import os

protocol SupabaseMatchIngestServing {
  func ingestMatchBundle(_ request: SupabaseMatchIngestService.MatchBundleRequest) async throws
    -> SupabaseMatchIngestService.SyncResult
  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws
    -> [SupabaseMatchIngestService.RemoteMatchBundle]
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

  private let clientProvider: SupabaseClientProviding
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let isoFormatter: ISO8601DateFormatter

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    encoder: JSONEncoder = SupabaseMatchIngestService.makeEncoder(),
    decoder: JSONDecoder = SupabaseMatchIngestService.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseMatchIngestService.makeISOFormatter())
  {
    self.clientProvider = clientProvider
    self.encoder = encoder
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func ingestMatchBundle(_ request: MatchBundleRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    // Get the current session and verify we have a valid token
    let session = try await supabaseClient.auth.session
    let authHeader = "Bearer \(session.accessToken)"

    #if DEBUG
    let tokenPrefix = String(session.accessToken.prefix(20))
    let userId = session.user.id
    AppLog.supabase.debug("Match ingest: user=\(userId) token_prefix=\(tokenPrefix, privacy: .public)")
    #endif

    let payload = try encoder.encode(request)

    // CRITICAL FIX: The Supabase Swift SDK's FunctionsClient.invoke() with custom
    // headers does NOT merge with setAuth() headers - it replaces them entirely.
    // We MUST explicitly include the Authorization header when using custom headers.
    let options = FunctionInvokeOptions(
      method: .post,
      headers: [
        "Authorization": authHeader,
        "Content-Type": "application/json",
        "Idempotency-Key": request.match.id.uuidString,
        "X-RefWatch-Client": "ios",
      ],
      body: payload)

    do {
      return try await supabaseClient.functionsClient.invoke(
        "matches-ingest",
        options: options)
      { data, _ in
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
          AppLog.supabase.debug("Match ingest raw response: \(responseString, privacy: .public)")
        }
        #endif

        return try self.decoder.decode(SyncResult.self, from: data)
      }
    } catch {
      #if DEBUG
      AppLog.supabase.error("Match ingest decoding error: \(error.localizedDescription, privacy: .public)")
      #endif
      throw error
    }
  }

  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteMatchBundle] {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    let matchSelect = [
      "id",
      "owner_id",
      "status",
      "started_at",
      "completed_at",
      "duration_seconds",
      "number_of_periods",
      "regulation_minutes",
      "half_time_minutes",
      "competition_id",
      "competition_name",
      "venue_id",
      "venue_name",
      "home_team_id",
      "home_team_name",
      "away_team_id",
      "away_team_name",
      "extra_time_enabled",
      "extra_time_half_minutes",
      "penalties_enabled",
      "penalty_initial_rounds",
      "home_score",
      "away_score",
      "final_score",
      "source_device_id",
      "updated_at",
    ].joined(separator: ", ")
    let eventSelect = [
      "id",
      "match_id",
      "occurred_at",
      "period_index",
      "clock_seconds",
      "match_time_label",
      "event_type",
      "payload",
      "team_side",
    ].joined(separator: ", ")
    let metricsSelect = [
      "match_id",
      "owner_id",
      "regulation_minutes",
      "half_time_minutes",
      "extra_time_minutes",
      "penalties_enabled",
      "total_goals",
      "total_cards",
      "total_penalties",
      "yellow_cards",
      "red_cards",
      "home_cards",
      "away_cards",
      "home_substitutions",
      "away_substitutions",
      "penalties_scored",
      "penalties_missed",
      "avg_added_time_seconds",
      "generated_at",
    ].joined(separator: ", ")

    let matches: [MatchRowDTO] = try await supabaseClient.fetchRows(
      SupabaseFetchRequest(
        table: "matches",
        columns: matchSelect,
        filters: makeMatchFilters(ownerId: ownerId, updatedAfter: updatedAfter),
        orderBy: "updated_at",
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    guard matches.isEmpty == false else { return [] }

    let matchIds = matches.map(\.id.uuidString)
    let periods: [PeriodRowDTO] = try await supabaseClient.fetchRows(
      SupabaseFetchRequest(
        table: "match_periods",
        columns: "id, match_id, index, regulation_seconds, added_time_seconds, result",
        filters: [.in("match_id", values: matchIds)],
        orderBy: nil,
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    let events: [EventRowDTO] = try await supabaseClient.fetchRows(
      SupabaseFetchRequest(
        table: "match_events",
        columns: eventSelect,
        filters: [.in("match_id", values: matchIds)],
        orderBy: "occurred_at",
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    let metricsRows: [MatchMetricsRowDTO] = try await supabaseClient.fetchRows(
      SupabaseFetchRequest(
        table: "match_metrics",
        columns: metricsSelect,
        filters: [.in("match_id", values: matchIds)],
        orderBy: nil,
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    let periodsByMatch = Dictionary(grouping: periods, by: { $0.matchId })
    let eventsByMatch = Dictionary(grouping: events, by: { $0.matchId })
    let metricsByMatch = Dictionary(uniqueKeysWithValues: metricsRows.map { ($0.matchId, $0.toRemoteMetrics()) })

    return matches.map { row in
      let remoteMatch = row.toRemoteMatch()
      let remotePeriods = (periodsByMatch[row.id] ?? []).map { $0.toRemotePeriod() }
      let remoteEvents = (eventsByMatch[row.id] ?? []).map { $0.toRemoteEvent() }
      let remoteMetrics = metricsByMatch[row.id]
      return RemoteMatchBundle(match: remoteMatch, periods: remotePeriods, events: remoteEvents, metrics: remoteMetrics)
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

extension SupabaseMatchIngestService {
  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)

      if let date = SupabaseDateParser.parse(
        value,
        isoWithFraction: isoWithFraction,
        isoWithoutFraction: isoWithoutFraction)
      {
        return date
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Cannot decode date from: \(value)")
    }
    return decoder
  }

  private static func makeISOFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }

  private func makeMatchFilters(ownerId: UUID, updatedAfter: Date?) -> [SupabaseQueryFilter] {
    var filters: [SupabaseQueryFilter] = [
      .equals("owner_id", value: ownerId.uuidString),
    ]
    if let updatedAfter {
      filters.append(.greaterThan("updated_at", value: self.isoFormatter.string(from: updatedAfter)))
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
      id: self.id,
      ownerId: self.ownerId,
      status: self.status,
      startedAt: self.startedAt,
      completedAt: self.completedAt,
      durationSeconds: self.durationSeconds,
      numberOfPeriods: self.numberOfPeriods,
      regulationMinutes: self.regulationMinutes,
      halfTimeMinutes: self.halfTimeMinutes,
      competitionId: self.competitionId,
      competitionName: self.competitionName,
      venueId: self.venueId,
      venueName: self.venueName,
      homeTeamId: self.homeTeamId,
      homeTeamName: self.homeTeamName,
      awayTeamId: self.awayTeamId,
      awayTeamName: self.awayTeamName,
      extraTimeEnabled: self.extraTimeEnabled,
      extraTimeHalfMinutes: self.extraTimeHalfMinutes,
      penaltiesEnabled: self.penaltiesEnabled,
      penaltyInitialRounds: self.penaltyInitialRounds,
      homeScore: self.homeScore,
      awayScore: self.awayScore,
      finalScore: self.finalScore,
      sourceDeviceId: self.sourceDeviceId,
      updatedAt: self.updatedAt)
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
      id: self.id,
      matchId: self.matchId,
      index: self.index,
      regulationSeconds: self.regulationSeconds,
      addedTimeSeconds: self.addedTimeSeconds,
      result: self.result)
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
      id: self.id,
      matchId: self.matchId,
      occurredAt: self.occurredAt,
      periodIndex: self.periodIndex,
      clockSeconds: self.clockSeconds,
      matchTimeLabel: self.matchTimeLabel,
      eventType: self.eventType,
      payload: self.payload,
      teamSide: self.teamSide)
  }
}

private struct MatchMetricsRowDTO: Decodable {
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
    case generatedAt = "generated_at"
  }

  func toRemoteMetrics() -> SupabaseMatchIngestService.RemoteMetrics {
    SupabaseMatchIngestService.RemoteMetrics(
      matchId: self.matchId,
      ownerId: self.ownerId,
      regulationMinutes: self.regulationMinutes,
      halfTimeMinutes: self.halfTimeMinutes,
      extraTimeMinutes: self.extraTimeMinutes,
      penaltiesEnabled: self.penaltiesEnabled,
      totalGoals: self.totalGoals,
      totalCards: self.totalCards,
      totalPenalties: self.totalPenalties,
      yellowCards: self.yellowCards,
      redCards: self.redCards,
      homeCards: self.homeCards,
      awayCards: self.awayCards,
      homeSubstitutions: self.homeSubstitutions,
      awaySubstitutions: self.awaySubstitutions,
      penaltiesScored: self.penaltiesScored,
      penaltiesMissed: self.penaltiesMissed,
      avgAddedTimeSeconds: self.avgAddedTimeSeconds,
      generatedAt: self.generatedAt)
  }
}
