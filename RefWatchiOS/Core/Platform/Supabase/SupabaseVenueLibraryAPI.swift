//
//  VenueRemoteContract.swift
//  RefWatchiOS
//
//  Network layer for syncing venues with Supabase.
//  Handles fetching, upserting, and deleting venue records.
//

import Foundation
import RefWatchCore

/// Protocol defining venue sync operations
protocol VenueRemoteServing {
  /// Fetch venues for a given owner, optionally filtering by updated_at
  func fetchVenues(ownerId: UUID, updatedAfter: Date?) async throws -> [VenueRemoteContract.RemoteVenue]

  /// Sync a venue to Supabase (upsert)
  func syncVenue(_ request: VenueRemoteContract.VenueRequest) async throws -> VenueRemoteContract.SyncResult

  /// Delete a venue from Supabase
  func deleteVenue(venueId: UUID) async throws
}

/// Supabase API client for venue library operations
struct VenueRemoteContract {
  /// Remote venue data structure
  struct RemoteVenue: Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date
    var deletedAt: Date? = nil
  }

  /// Request structure for creating/updating venues
  struct VenueRequest: Equatable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
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
