//
//  SupabaseTeamLibraryAPI.swift
//  RefWatchiOS
//
//  Network layer for syncing the Team Library with Supabase tables. Handles
//  fetching, upserting, and deleting teams alongside their related members,
//  officials, and tags.
//

import Foundation
import Supabase

protocol SupabaseTeamLibraryServing {
  func fetchTeams(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseTeamLibraryAPI.RemoteTeam]
  func syncTeamBundle(_ request: SupabaseTeamLibraryAPI.TeamBundleRequest) async throws -> SupabaseTeamLibraryAPI.SyncResult
  func deleteTeam(teamId: UUID) async throws
}

struct SupabaseTeamLibraryAPI: SupabaseTeamLibraryServing {
  struct RemoteTeam: Equatable {
    struct Team: Equatable {
      let id: UUID
      let ownerId: UUID
      let name: String
      let shortName: String?
      let division: String?
      let primaryColorHex: String?
      let secondaryColorHex: String?
      let createdAt: Date
      let updatedAt: Date
    }

    struct Member: Equatable {
      let id: UUID
      let teamId: UUID
      let displayName: String
      let jerseyNumber: String?
      let role: String?
      let position: String?
      let notes: String?
      let createdAt: Date
    }

    struct Official: Equatable {
      let id: UUID
      let teamId: UUID
      let displayName: String
      let role: String
      let phone: String?
      let email: String?
      let createdAt: Date
    }

    struct Tag: Equatable {
      let teamId: UUID
      let value: String
    }

    let team: Team
    let members: [Member]
    let officials: [Official]
    let tags: [Tag]
  }

  struct TeamInput: Equatable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let shortName: String?
    let division: String?
    let primaryColorHex: String?
    let secondaryColorHex: String?
  }

  struct MemberInput: Equatable {
    let id: UUID
    let teamId: UUID
    let displayName: String
    let jerseyNumber: String?
    let role: String?
    let position: String?
    let notes: String?
    let createdAt: Date?
  }

  struct OfficialInput: Equatable {
    let id: UUID
    let teamId: UUID
    let displayName: String
    let role: String
    let phone: String?
    let email: String?
    let createdAt: Date?
  }

  struct TeamBundleRequest: Equatable {
    let team: TeamInput
    let members: [MemberInput]
    let officials: [OfficialInput]
    let tags: [String]
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
    decoder: JSONDecoder = SupabaseTeamLibraryAPI.makeDecoder(),
    isoFormatter: ISO8601DateFormatter = SupabaseTeamLibraryAPI.makeISOFormatter()
  ) {
    self.clientProvider = clientProvider
    self.decoder = decoder
    self.isoFormatter = isoFormatter
  }

  func fetchTeams(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteTeam] {
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

    let teamRows: [TeamRowDTO] = try await supabaseClient.fetchRows(
      from: "teams",
      select: "id, owner_id, name, short_name, division, color_primary, color_secondary, created_at, updated_at",
      filters: filters,
      orderBy: "updated_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    if teamRows.isEmpty {
      return []
    }

    let teamIds = teamRows.map { $0.id }

    let members = try await fetchMembers(client: supabaseClient, teamIds: teamIds)
    let officials = try await fetchOfficials(client: supabaseClient, teamIds: teamIds)
    let tags = try await fetchTags(client: supabaseClient, teamIds: teamIds)

    let membersByTeam = Dictionary(grouping: members, by: { $0.teamId })
    let officialsByTeam = Dictionary(grouping: officials, by: { $0.teamId })
    let tagsByTeam = Dictionary(grouping: tags, by: { $0.teamId })

    return teamRows.map { row in
      let remoteTeam = RemoteTeam.Team(
        id: row.id,
        ownerId: row.ownerId,
        name: row.name,
        shortName: row.shortName,
        division: row.division,
        primaryColorHex: row.colorPrimary,
        secondaryColorHex: row.colorSecondary,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
      )
      return RemoteTeam(
        team: remoteTeam,
        members: membersByTeam[row.id] ?? [],
        officials: officialsByTeam[row.id] ?? [],
        tags: tagsByTeam[row.id] ?? []
      )
    }
  }

  func syncTeamBundle(_ request: TeamBundleRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    let teamPayload = TeamUpsertDTO(
      id: request.team.id,
      ownerId: request.team.ownerId,
      name: request.team.name,
      shortName: request.team.shortName,
      division: request.team.division,
      colorPrimary: request.team.primaryColorHex,
      colorSecondary: request.team.secondaryColorHex
    )

    let teamResponse = try await supabaseClient
      .from("teams")
      .upsert([teamPayload], onConflict: "id", returning: .representation)
      .execute()

    let updatedTeams = try decoder.decode([TeamRowDTO].self, from: teamResponse.data)
    guard let updatedTeam = updatedTeams.first else {
      throw APIError.invalidResponse
    }

    try await replaceMembers(client: supabaseClient, teamId: request.team.id, members: request.members)
    try await replaceOfficials(client: supabaseClient, teamId: request.team.id, officials: request.officials)
    try await replaceTags(client: supabaseClient, teamId: request.team.id, tags: request.tags)

    return SyncResult(updatedAt: updatedTeam.updatedAt)
  }

  func deleteTeam(teamId: UUID) async throws {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else {
      throw APIError.unsupportedClient
    }

    _ = try await supabaseClient
      .from("teams")
      .delete()
      .eq("id", value: teamId.uuidString)
      .execute()
  }
 }

// MARK: - DTO Helpers (top-level, file-private)

fileprivate struct TeamRowDTO: Decodable, Sendable {
  let id: UUID
  let ownerId: UUID
  let name: String
  let shortName: String?
  let division: String?
  let colorPrimary: String?
  let colorSecondary: String?
  let createdAt: Date
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case name
    case shortName = "short_name"
    case division
    case colorPrimary = "color_primary"
    case colorSecondary = "color_secondary"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

fileprivate struct MemberRowDTO: Decodable, Sendable {
  let id: UUID
  let teamId: UUID
  let displayName: String
  let jerseyNumber: String?
  let role: String?
  let position: String?
  let notes: String?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case teamId = "team_id"
    case displayName = "display_name"
    case jerseyNumber = "jersey_number"
    case role
    case position
    case notes
    case createdAt = "created_at"
  }
}

fileprivate struct OfficialRowDTO: Decodable, Sendable {
  let id: UUID
  let teamId: UUID
  let displayName: String
  let role: String
  let phone: String?
  let email: String?
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case teamId = "team_id"
    case displayName = "display_name"
    case role
    case phone
    case email
    case createdAt = "created_at"
  }
}

fileprivate struct TagRowDTO: Decodable, Sendable {
  let teamId: UUID
  let tag: String

  enum CodingKeys: String, CodingKey {
    case teamId = "team_id"
    case tag
  }
}

fileprivate struct TeamUpsertDTO: Sendable {
  let id: UUID
  let ownerId: UUID
  let name: String
  let shortName: String?
  let division: String?
  let colorPrimary: String?
  let colorSecondary: String?

  enum CodingKeys: String, CodingKey {
    case id
    case ownerId = "owner_id"
    case name
    case shortName = "short_name"
    case division
    case colorPrimary = "color_primary"
    case colorSecondary = "color_secondary"
  }
}

fileprivate struct MemberUpsertDTO: Sendable {
  let id: UUID
  let teamId: UUID
  let displayName: String
  let jerseyNumber: String?
  let role: String?
  let position: String?
  let notes: String?
  let createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case teamId = "team_id"
    case displayName = "display_name"
    case jerseyNumber = "jersey_number"
    case role
    case position
    case notes
    case createdAt = "created_at"
  }
}

fileprivate struct OfficialUpsertDTO: Sendable {
  let id: UUID
  let teamId: UUID
  let displayName: String
  let role: String
  let phone: String?
  let email: String?
  let createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case teamId = "team_id"
    case displayName = "display_name"
    case role
    case phone
    case email
    case createdAt = "created_at"
  }
}

fileprivate struct TagUpsertDTO: Sendable {
  let teamId: UUID
  let tag: String

  enum CodingKeys: String, CodingKey {
    case teamId = "team_id"
    case tag
  }
}

// Provide nonisolated Encodable conformances to avoid main-actor isolated synthesis

nonisolated extension TeamUpsertDTO: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(ownerId, forKey: .ownerId)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(shortName, forKey: .shortName)
    try container.encodeIfPresent(division, forKey: .division)
    try container.encodeIfPresent(colorPrimary, forKey: .colorPrimary)
    try container.encodeIfPresent(colorSecondary, forKey: .colorSecondary)
  }
}

nonisolated extension MemberUpsertDTO: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(teamId, forKey: .teamId)
    try container.encode(displayName, forKey: .displayName)
    try container.encodeIfPresent(jerseyNumber, forKey: .jerseyNumber)
    try container.encodeIfPresent(role, forKey: .role)
    try container.encodeIfPresent(position, forKey: .position)
    try container.encodeIfPresent(notes, forKey: .notes)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
  }
}

nonisolated extension OfficialUpsertDTO: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(teamId, forKey: .teamId)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(role, forKey: .role)
    try container.encodeIfPresent(phone, forKey: .phone)
    try container.encodeIfPresent(email, forKey: .email)
    try container.encodeIfPresent(createdAt, forKey: .createdAt)
  }
}

nonisolated extension TagUpsertDTO: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(teamId, forKey: .teamId)
    try container.encode(tag, forKey: .tag)
  }
}

// MARK: - Query helpers

private extension SupabaseTeamLibraryAPI {
  func fetchMembers(client: SupabaseClient, teamIds: [UUID]) async throws -> [RemoteTeam.Member] {
    guard teamIds.isEmpty == false else { return [] }
    let idStrings = teamIds.map { $0.uuidString }
    let rows: [MemberRowDTO] = try await client.fetchRows(
      from: "team_members",
      select: "id, team_id, display_name, jersey_number, role, position, notes, created_at",
      filters: [.in("team_id", values: idStrings)],
      orderBy: "created_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    return rows.map { row in
      RemoteTeam.Member(
        id: row.id,
        teamId: row.teamId,
        displayName: row.displayName,
        jerseyNumber: row.jerseyNumber,
        role: row.role,
        position: row.position,
        notes: row.notes,
        createdAt: row.createdAt
      )
    }
  }

  func fetchOfficials(client: SupabaseClient, teamIds: [UUID]) async throws -> [RemoteTeam.Official] {
    guard teamIds.isEmpty == false else { return [] }
    let idStrings = teamIds.map { $0.uuidString }
    let rows: [OfficialRowDTO] = try await client.fetchRows(
      from: "team_officials",
      select: "id, team_id, display_name, role, phone, email, created_at",
      filters: [.in("team_id", values: idStrings)],
      orderBy: "created_at",
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    return rows.map { row in
      RemoteTeam.Official(
        id: row.id,
        teamId: row.teamId,
        displayName: row.displayName,
        role: row.role,
        phone: row.phone,
        email: row.email,
        createdAt: row.createdAt
      )
    }
  }

  func fetchTags(client: SupabaseClient, teamIds: [UUID]) async throws -> [RemoteTeam.Tag] {
    guard teamIds.isEmpty == false else { return [] }
    let idStrings = teamIds.map { $0.uuidString }
    let rows: [TagRowDTO] = try await client.fetchRows(
      from: "team_tags",
      select: "team_id, tag",
      filters: [.in("team_id", values: idStrings)],
      orderBy: nil,
      ascending: true,
      limit: 0,
      decoder: decoder
    )

    return rows.map { row in
      RemoteTeam.Tag(teamId: row.teamId, value: row.tag)
    }
  }

  func replaceMembers(client: SupabaseClient, teamId: UUID, members: [MemberInput]) async throws {
    _ = try await client
      .from("team_members")
      .delete()
      .eq("team_id", value: teamId.uuidString)
      .execute()

    guard members.isEmpty == false else { return }

    let payload = members.map { member in
      MemberUpsertDTO(
        id: member.id,
        teamId: member.teamId,
        displayName: member.displayName,
        jerseyNumber: member.jerseyNumber,
        role: member.role,
        position: member.position,
        notes: member.notes,
        createdAt: member.createdAt
      )
    }

    _ = try await client
      .from("team_members")
      .upsert(payload, onConflict: "id", returning: .minimal)
      .execute()
  }

  func replaceOfficials(client: SupabaseClient, teamId: UUID, officials: [OfficialInput]) async throws {
    _ = try await client
      .from("team_officials")
      .delete()
      .eq("team_id", value: teamId.uuidString)
      .execute()

    guard officials.isEmpty == false else { return }

    let payload = officials.map { official in
      OfficialUpsertDTO(
        id: official.id,
        teamId: official.teamId,
        displayName: official.displayName,
        role: official.role,
        phone: official.phone,
        email: official.email,
        createdAt: official.createdAt
      )
    }

    _ = try await client
      .from("team_officials")
      .upsert(payload, onConflict: "id", returning: .minimal)
      .execute()
  }

  func replaceTags(client: SupabaseClient, teamId: UUID, tags: [String]) async throws {
    _ = try await client
      .from("team_tags")
      .delete()
      .eq("team_id", value: teamId.uuidString)
      .execute()

    guard tags.isEmpty == false else { return }

    let payload = tags.map { tag in
      TagUpsertDTO(teamId: teamId, tag: tag)
    }

    _ = try await client
      .from("team_tags")
      .upsert(payload, onConflict: "team_id,tag", returning: .minimal)
      .execute()
  }
}

// MARK: - Formatters

private extension SupabaseTeamLibraryAPI {
  static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      if let date = makeISOFormatter().date(from: value) {
        return date
      }
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Invalid ISO8601 date: \(value)"
        )
      )
    }
    return decoder
  }

  static func makeISOFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
  }
}
