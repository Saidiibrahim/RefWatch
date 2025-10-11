//
//  SupabaseScheduleAPI.swift
//  RefZoneiOS
//
//  Network layer for syncing scheduled matches with Supabase. Mirrors the
//  structure introduced for the team library so repositories can reuse the
//  same push/pull pattern.
//

import Foundation
import OSLog
import Supabase

protocol SupabaseScheduleServing {
  func fetchScheduledMatches(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseScheduleAPI.RemoteScheduledMatch]
  func syncScheduledMatch(_ request: SupabaseScheduleAPI.UpsertRequest) async throws -> SupabaseScheduleAPI.SyncResult
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
  private let log = AppLog.supabase

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    decoder: JSONDecoder = SupabaseScheduleAPI.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseScheduleAPI.makeISOFormatter()
  ) {
    self.clientProvider = clientProvider
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func fetchScheduledMatches(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteScheduledMatch] {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    var filters: [SupabaseQueryFilter] = [
      .equals("owner_id", value: ownerId.uuidString)
    ]
    if let updatedAfter {
      let value = isoFormatter.string(from: updatedAfter)
      filters.append(.greaterThan("updated_at", value: value))
    }

    let rows: [ScheduledMatchRowDTO] = try await supabaseClient.fetchRows(
      from: "scheduled_matches",
      select: "id, owner_id, home_team_name, away_team_name, home_team_id, away_team_id, kickoff_at, status, competition_id, competition_name, venue_id, venue_name, notes, source_device_id, created_at, updated_at",
      filters: filters,
      orderBy: "updated_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    return rows.map { row in
      RemoteScheduledMatch(
        id: row.id,
        ownerId: row.ownerId,
        homeTeamName: row.homeTeamName,
        awayTeamName: row.awayTeamName,
        kickoffAt: row.kickoffAt,
        status: ScheduledMatch.Status(rawValue: row.status) ?? .scheduled,
        competitionId: row.competitionId,
        competitionName: row.competitionName,
        venueId: row.venueId,
        venueName: row.venueName,
        homeTeamId: row.homeTeamId,
        awayTeamId: row.awayTeamId,
        notes: row.notes,
        sourceDeviceId: row.sourceDeviceId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
      )
    }
  }

  func syncScheduledMatch(_ request: UpsertRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    let payload = ScheduledMatchUpsertDTO(
      id: request.id,
      ownerId: request.ownerId,
      homeTeamName: request.homeTeamName,
      awayTeamName: request.awayTeamName,
      homeTeamId: request.homeTeamId,
      awayTeamId: request.awayTeamId,
      kickoffAt: request.kickoffAt,
      status: request.status.rawValue,
      competitionId: request.competitionId,
      competitionName: request.competitionName,
      venueId: request.venueId,
      venueName: request.venueName,
      notes: request.notes,
      sourceDeviceId: request.sourceDeviceId
    )

    let response = try await supabaseClient
      .from("scheduled_matches")
      .upsert([payload], onConflict: "id", returning: .representation)
      .execute()

    if let raw = String(data: response.data, encoding: .utf8) {
      log.debug("Scheduled match upsert response: \(raw, privacy: .public)")
    } else {
      log.debug("Scheduled match upsert response size=\(response.data.count, privacy: .public) bytes")
    }

    let updatedRows = try Self.decodeUpsertResponse(data: response.data, decoder: decoder)
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
        debugDescription: "Invalid date string: \(value)"
      )
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

private extension SupabaseScheduleAPI {
  static func parseTimestamp(
    _ value: String,
    isoWithFraction: ISO8601DateFormatter,
    isoWithoutFraction: ISO8601DateFormatter
  ) -> Date? {
    if let date = isoWithFraction.date(from: value) ?? isoWithoutFraction.date(from: value) {
      return date
    }

    let normalized = normalizePostgresTimestamp(value)
    return isoWithFraction.date(from: normalized) ?? isoWithoutFraction.date(from: normalized)
  }

  static func normalizePostgresTimestamp(_ value: String) -> String {
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
    case kickoffAt = "kickoff_at"
    case status
    case competitionId = "competition_id"
    case competitionName = "competition_name"
    case venueId = "venue_id"
    case venueName = "venue_name"
    case notes
    case sourceDeviceId = "source_device_id"
  }

  // Explicit nonisolated Encodable conformance so it can be used with Sendable generics (Supabase upsert).
  nonisolated func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(ownerId, forKey: .ownerId)
    try container.encode(homeTeamName, forKey: .homeTeamName)
    try container.encode(awayTeamName, forKey: .awayTeamName)
    try container.encodeIfPresent(homeTeamId, forKey: .homeTeamId)
    try container.encodeIfPresent(awayTeamId, forKey: .awayTeamId)
    try container.encode(kickoffAt, forKey: .kickoffAt)
    try container.encode(status, forKey: .status)
    try container.encodeIfPresent(competitionId, forKey: .competitionId)
    try container.encodeIfPresent(competitionName, forKey: .competitionName)
    try container.encodeIfPresent(venueId, forKey: .venueId)
    try container.encodeIfPresent(venueName, forKey: .venueName)
    try container.encodeIfPresent(notes, forKey: .notes)
    try container.encodeIfPresent(sourceDeviceId, forKey: .sourceDeviceId)
  }
}
