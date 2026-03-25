//
//  SupabaseScheduleAPI.swift
//  RefWatchiOS
//
//  Network layer for syncing scheduled matches with Supabase. Mirrors the
//  structure introduced for the team library so repositories can reuse the
//  same push/pull pattern.
//

import Foundation
import RefWatchCore
import Supabase

protocol SupabaseScheduleServing {
  func fetchScheduledMatches(
    ownerId: UUID,
    updatedAfter: Date?) async throws -> [SupabaseScheduleAPI.RemoteScheduledMatch]
  func syncScheduledMatch(
    _ request: SupabaseScheduleAPI.UpsertRequest) async throws -> SupabaseScheduleAPI.SyncResult
  func deleteScheduledMatch(id: UUID) async throws
}

struct SupabaseScheduleAPI: SupabaseScheduleServing {
  struct RemoteScheduledMatch: Equatable {
    let id: UUID
    let ownerId: UUID
    let homeTeamName: String
    let awayTeamName: String
    let kickoffAt: Date
    let status: ScheduledMatch.Status
    let competitionId: UUID?
    let competitionName: String?
    let venueId: UUID?
    let venueName: String?
    let homeTeamId: UUID?
    let awayTeamId: UUID?
    let homeMatchSheet: ScheduledMatchSheet?
    let awayMatchSheet: ScheduledMatchSheet?
    let notes: String?
    let sourceDeviceId: String?
    let createdAt: Date
    let updatedAt: Date
  }

  struct UpsertRequest: Equatable {
    let id: UUID
    let ownerId: UUID
    let homeTeamName: String
    let awayTeamName: String
    let kickoffAt: Date
    let status: ScheduledMatch.Status
    let competitionId: UUID?
    let competitionName: String?
    let venueId: UUID?
    let venueName: String?
    let homeTeamId: UUID?
    let awayTeamId: UUID?
    let homeMatchSheet: ScheduledMatchSheet?
    let awayMatchSheet: ScheduledMatchSheet?
    let notes: String?
    let sourceDeviceId: String?
  }

  struct SyncResult: Equatable {
    let updatedAt: Date
  }

  enum APIError: Error, Equatable {
    case unsupportedClient
    case invalidResponse
  }

  private let clientProvider: SupabaseClientProviding
  private let decoder: JSONDecoder
  private let isoFormatter: ISO8601DateFormatter
  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    decoder: JSONDecoder = SupabaseScheduleAPI.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseScheduleAPI.makeISOFormatter())
  {
    self.clientProvider = clientProvider
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func fetchScheduledMatches(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteScheduledMatch] {
    let client = try await clientProvider.authorizedClient()

    var filters: [SupabaseQueryFilter] = [
      .equals("owner_id", value: ownerId.uuidString),
    ]
    if let updatedAfter {
      let value = self.isoFormatter.string(from: updatedAfter)
      filters.append(.greaterThan("updated_at", value: value))
    }

    let selectColumns = [
      "id",
      "owner_id",
      "home_team_name",
      "away_team_name",
      "home_team_id",
      "away_team_id",
      "home_match_sheet",
      "away_match_sheet",
      "kickoff_at",
      "status",
      "competition_id",
      "competition_name",
      "venue_id",
      "venue_name",
      "notes",
      "source_device_id",
      "created_at",
      "updated_at",
    ].joined(separator: ", ")
    let rows: [ScheduledMatchRowDTO] = try await client.fetchRows(
      SupabaseFetchRequest(
        table: "scheduled_matches",
        columns: selectColumns,
        filters: filters,
        orderBy: "updated_at",
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    return rows.map { row in
      RemoteScheduledMatch(
        id: row.id,
        ownerId: row.ownerId,
        homeTeamName: row.homeTeamName,
        awayTeamName: row.awayTeamName,
        kickoffAt: row.kickoffAt,
        status: ScheduledMatch.Status(fromDatabase: row.status),
        competitionId: row.competitionId,
        competitionName: row.competitionName,
        venueId: row.venueId,
        venueName: row.venueName,
        homeTeamId: row.homeTeamId,
        awayTeamId: row.awayTeamId,
        homeMatchSheet: row.homeMatchSheet,
        awayMatchSheet: row.awayMatchSheet,
        notes: row.notes,
        sourceDeviceId: row.sourceDeviceId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt)
    }
  }

  func syncScheduledMatch(_ request: UpsertRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()

    let payload = ScheduledMatchUpsertDTO(
      id: request.id,
      ownerId: request.ownerId,
      homeTeamName: request.homeTeamName,
      awayTeamName: request.awayTeamName,
      homeTeamId: request.homeTeamId,
      awayTeamId: request.awayTeamId,
      homeMatchSheet: request.homeMatchSheet?.normalized(),
      awayMatchSheet: request.awayMatchSheet?.normalized(),
      kickoffAt: request.kickoffAt,
      status: request.status.databaseValue,
      competitionId: request.competitionId,
      competitionName: request.competitionName,
      venueId: request.venueId,
      venueName: request.venueName,
      notes: request.notes,
      sourceDeviceId: request.sourceDeviceId)

    let updatedRows: [ScheduledMatchRowDTO] = try await client.upsertRows(
      into: "scheduled_matches",
      payload: [payload],
      onConflict: "id",
      decoder: self.decoder)
    guard let updated = updatedRows.first else {
      throw APIError.invalidResponse
    }

    return SyncResult(updatedAt: updated.updatedAt)
  }

  func deleteScheduledMatch(id: UUID) async throws {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    _ = try await supabaseClient
      .from("scheduled_matches")
      .delete()
      .eq("id", value: id.uuidString)
      .execute()
  }
}

extension SupabaseScheduleAPI {
  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]

    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)

      if let date = parseTimestamp(value, isoWithFraction: isoWithFraction, isoWithoutFraction: isoWithoutFraction) {
        return date
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid date string: \(value)")
    }

    return decoder
  }

  static func decodeUpsertResponse(data: Data, decoder: JSONDecoder) throws -> [ScheduledMatchRowDTO] {
    if data.isEmpty {
      return []
    }

    if let rows = try? decoder.decode([ScheduledMatchRowDTO].self, from: data) {
      return rows
    }

    struct Representation: Decodable {
      let data: [ScheduledMatchRowDTO]
    }

    if let wrapped = try? decoder.decode(Representation.self, from: data) {
      return wrapped.data
    }

    throw APIError.invalidResponse
  }

  static func makeISOFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}

extension SupabaseScheduleAPI {
  fileprivate static func parseTimestamp(
    _ value: String,
    isoWithFraction: ISO8601DateFormatter,
    isoWithoutFraction: ISO8601DateFormatter) -> Date?
  {
    if let date = isoWithFraction.date(from: value) ?? isoWithoutFraction.date(from: value) {
      return date
    }

    let normalized = self.normalizePostgresTimestamp(value)
    return isoWithFraction.date(from: normalized) ?? isoWithoutFraction.date(from: normalized)
  }

  fileprivate static func normalizePostgresTimestamp(_ value: String) -> String {
    var result = value

    if let spaceIndex = result.firstIndex(of: " ") {
      result.replaceSubrange(spaceIndex...spaceIndex, with: "T")
    }

    guard let tzIndex = result.lastIndex(where: { $0 == "+" || $0 == "-" }) else {
      return result
    }

    let prefix = String(result[..<tzIndex])
    let suffix = String(result[tzIndex...])

    if suffix.contains(":") {
      return prefix + suffix
    }

    if suffix.count == 3 {
      return prefix + suffix + ":00"
    }

    if suffix.count == 5 {
      let hour = suffix.prefix(3)
      let minutes = suffix.suffix(2)
      return prefix + hour + ":" + minutes
    }

    return prefix + suffix
  }
}

// Top-level DTOs (private) to avoid inheriting any actor isolation from enclosing types.

struct ScheduledMatchRowDTO: Decodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let homeTeamName: String
  let awayTeamName: String
  let homeTeamId: UUID?
  let awayTeamId: UUID?
  let homeMatchSheet: ScheduledMatchSheet?
  let awayMatchSheet: ScheduledMatchSheet?
  let kickoffAt: Date
  let status: String
  let competitionId: UUID?
  let competitionName: String?
  let venueId: UUID?
  let venueName: String?
  let notes: String?
  let sourceDeviceId: String?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case homeTeamName = "home_team_name"
    case awayTeamName = "away_team_name"
    case homeTeamId = "home_team_id"
    case awayTeamId = "away_team_id"
    case homeMatchSheet = "home_match_sheet"
    case awayMatchSheet = "away_match_sheet"
    case kickoffAt = "kickoff_at"
    case status
    case competitionId = "competition_id"
    case competitionName = "competition_name"
    case venueId = "venue_id"
    case venueName = "venue_name"
    case notes
    case sourceDeviceId = "source_device_id"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

private struct ScheduledMatchUpsertDTO: Encodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let homeTeamName: String
  let awayTeamName: String
  let homeTeamId: UUID?
  let awayTeamId: UUID?
  let homeMatchSheet: ScheduledMatchSheet?
  let awayMatchSheet: ScheduledMatchSheet?
  let kickoffAt: Date
  let status: String
  let competitionId: UUID?
  let competitionName: String?
  let venueId: UUID?
  let venueName: String?
  let notes: String?
  let sourceDeviceId: String?

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case homeTeamName = "home_team_name"
    case awayTeamName = "away_team_name"
    case homeTeamId = "home_team_id"
    case awayTeamId = "away_team_id"
    case homeMatchSheet = "home_match_sheet"
    case awayMatchSheet = "away_match_sheet"
    case kickoffAt = "kickoff_at"
    case status
    case competitionId = "competition_id"
    case competitionName = "competition_name"
    case venueId = "venue_id"
    case venueName = "venue_name"
    case notes
    case sourceDeviceId = "source_device_id"
  }
}
