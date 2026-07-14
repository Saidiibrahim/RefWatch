//
//  CompetitionRemoteContract.swift
//  RefWatchiOS
//
//  Network layer for syncing competitions with Supabase.
//  Handles fetching, upserting, and deleting competition records.
//

import Foundation
import RefWatchCore

/// Protocol defining competition sync operations
protocol CompetitionRemoteServing {
  /// Fetch competitions for a given owner, optionally filtering by updated_at
  func fetchCompetitions(
    ownerId: UUID,
    updatedAfter: Date?) async throws -> [CompetitionRemoteContract.RemoteCompetition]

  /// Sync a competition to Supabase (upsert)
  func syncCompetition(
    _ request: CompetitionRemoteContract.CompetitionRequest) async throws -> CompetitionRemoteContract
    .SyncResult

  /// Delete a competition from Supabase
  func deleteCompetition(competitionId: UUID) async throws
}

/// Supabase API client for competition library operations
struct CompetitionRemoteContract {
  /// Remote competition data structure
  struct RemoteCompetition: Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let level: String?
    let createdAt: Date
    let updatedAt: Date
    var deletedAt: Date? = nil
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

}
