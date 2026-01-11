//
//  SupabaseCompetitionLibraryAPI.swift
//  RefWatchiOS
//
//  Network layer for syncing competitions with Supabase.
//  Handles fetching, upserting, and deleting competition records.
//

import Foundation
import RefWatchCore
import Supabase

/// Protocol defining competition sync operations
protocol SupabaseCompetitionLibraryServing {
  /// Fetch competitions for a given owner, optionally filtering by updated_at
  func fetchCompetitions(
    ownerId: UUID,
    updatedAfter: Date?) async throws -> [SupabaseCompetitionLibraryAPI.RemoteCompetition]

  /// Sync a competition to Supabase (upsert)
  func syncCompetition(
    _ request: SupabaseCompetitionLibraryAPI.CompetitionRequest) async throws -> SupabaseCompetitionLibraryAPI
    .SyncResult

  /// Delete a competition from Supabase
  func deleteCompetition(competitionId: UUID) async throws
}

/// Supabase API client for competition library operations
struct SupabaseCompetitionLibraryAPI: SupabaseCompetitionLibraryServing {
  /// Remote competition data structure
  struct RemoteCompetition: Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let level: String?
    let createdAt: Date
    let updatedAt: Date
  }

  /// Request structure for creating/updating competitions
  struct CompetitionRequest: Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let level: String?
  }

  /// Result of a sync operation
  struct SyncResult: Equatable, Sendable {
    let updatedAt: Date
  }

  enum APIError: Error, Equatable, Sendable {
    case unsupportedClient
    case invalidResponse
  }

  private let clientProvider: SupabaseClientProviding
  private let decoder: JSONDecoder
  private let isoFormatter: ISO8601DateFormatter

  init(
    clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
    decoder: JSONDecoder = SupabaseCompetitionLibraryAPI.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseCompetitionLibraryAPI.makeISOFormatter())
  {
    self.clientProvider = clientProvider
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func fetchCompetitions(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteCompetition] {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    var filters: [SupabaseQueryFilter] = [
      .equals("owner_id", value: ownerId.uuidString),
    ]
    if let updatedAfter {
      let value = self.isoFormatter.string(from: updatedAfter)
      filters.append(.greaterThan("updated_at", value: value))
    }

    let rows: [CompetitionRowDTO] = try await supabaseClient.fetchRows(
      SupabaseFetchRequest(
        table: "competitions",
        columns: "id, owner_id, name, level, created_at, updated_at",
        filters: filters,
        orderBy: "name",
        ascending: true,
        limit: 0,
        decoder: self.decoder))

    return rows.map { row in
      RemoteCompetition(
        id: row.id,
        ownerId: row.ownerId,
        name: row.name,
        level: row.level,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt)
    }
  }

  func syncCompetition(_ request: CompetitionRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    let payload = CompetitionUpsertDTO(
      id: request.id,
      ownerId: request.ownerId,
      name: request.name,
      level: request.level)

    let response: [CompetitionResponseDTO] = try await supabaseClient.upsertRows(
      into: "competitions",
      payload: payload,
      onConflict: "id",
      decoder: self.decoder)

    guard let first = response.first else {
      throw APIError.invalidResponse
    }

    return SyncResult(updatedAt: first.updatedAt)
  }

  func deleteCompetition(competitionId: UUID) async throws {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    _ = try await supabaseClient
      .from("competitions")
      .delete()
      .eq("id", value: competitionId.uuidString)
      .execute()
  }

  // MARK: - JSON Helpers

  static func makeDecoder() -> JSONDecoder {
    SupabaseJSONDecoderFactory.makeDecoder()
  }

  static func makeISOFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}

// MARK: - Data Transfer Objects

/// DTO for fetching competitions from Supabase
private struct CompetitionRowDTO: Decodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let name: String
  let level: String?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case name
    case level
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

/// DTO for upserting competitions to Supabase
private struct CompetitionUpsertDTO: Encodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let name: String
  let level: String?

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case name
    case level
  }
}

/// DTO for competition response after upsert
private struct CompetitionResponseDTO: Decodable, Sendable {
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case updatedAt = "updated_at"
  }
}
