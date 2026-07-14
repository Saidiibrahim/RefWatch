//
//  TeamRemoteContract.swift
//  RefWatchiOS
//
//  Network layer for syncing the Team Library with Supabase tables. Handles
//  fetching, upserting, and deleting teams alongside their related members,
//  officials, and tags.
//

import Foundation

protocol TeamRemoteServing {
  func fetchTeams(
    ownerId: UUID,
    updatedAfter: Date?) async throws -> [TeamRemoteContract.RemoteTeam]
  func syncTeamBundle(
    _ request: TeamRemoteContract.TeamBundleRequest) async throws -> TeamRemoteContract.SyncResult
  func importReferenceTeamsForCurrentUser(
    seasonYear: Int,
    competitionCodes: [String]?) async throws -> TeamRemoteContract.ReferenceTeamImportResult
  func deleteTeam(teamId: UUID) async throws
}

struct TeamRemoteContract {
  struct ReferenceTeamImportResult: Equatable {
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
  }

  struct RemoteTeam: Equatable {
    struct Team: Equatable {
      let id: UUID
      let ownerId: UUID
      let name: String
      let shortName: String?
      let division: String?
      let primaryColorHex: String?
      let secondaryColorHex: String?
      let referenceKey: String?
      let createdAt: Date
      let updatedAt: Date
      var deletedAt: Date? = nil
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
    let referenceKey: String?
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

}
