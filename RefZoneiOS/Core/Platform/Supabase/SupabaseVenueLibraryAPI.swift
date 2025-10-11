//
//  SupabaseVenueLibraryAPI.swift
//  RefZoneiOS
//
//  Network layer for syncing venues with Supabase.
//  Handles fetching, upserting, and deleting venue records.
//

import Foundation
import RefWatchCore
import Supabase

/// Protocol defining venue sync operations
protocol SupabaseVenueLibraryServing {
    /// Fetch venues for a given owner, optionally filtering by updated_at
    func fetchVenues(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseVenueLibraryAPI.RemoteVenue]

    /// Sync a venue to Supabase (upsert)
    func syncVenue(_ request: SupabaseVenueLibraryAPI.VenueRequest) async throws -> SupabaseVenueLibraryAPI.SyncResult

    /// Delete a venue from Supabase
    func deleteVenue(venueId: UUID) async throws
}

/// Supabase API client for venue library operations
struct SupabaseVenueLibraryAPI: SupabaseVenueLibraryServing {
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

    private let clientProvider: SupabaseClientProviding
    private let decoder: JSONDecoder
    private let isoFormatter: ISO8601DateFormatter

    init(
        clientProvider: SupabaseClientProviding = SupabaseClientProvider.shared,
        decoder: JSONDecoder = SupabaseVenueLibraryAPI.makeDecoder(),
        isoFormatter: ISO8601DateFormatter = SupabaseVenueLibraryAPI.makeISOFormatter()
    ) {
        self.clientProvider = clientProvider
        self.decoder = decoder
        self.isoFormatter = isoFormatter
    }

    func fetchVenues(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteVenue] {
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

        let rows: [VenueRowDTO] = try await supabaseClient.fetchRows(
            from: "venues",
            select: "id, owner_id, name, city, country, latitude, longitude, created_at, updated_at",
            filters: filters,
            orderBy: "name",
            ascending: true,
            limit: 0,
            decoder: decoder
        )

        return rows.map { row in
            RemoteVenue(
                id: row.id,
                ownerId: row.ownerId,
                name: row.name,
                city: row.city,
                country: row.country,
                latitude: row.latitude,
                longitude: row.longitude,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }

    func syncVenue(_ request: VenueRequest) async throws -> SyncResult {
        let client = try await clientProvider.authorizedClient()
        guard let supabaseClient = client as? SupabaseClient else {
            throw APIError.unsupportedClient
        }

        let payload = VenueUpsertDTO(
            id: request.id,
            ownerId: request.ownerId,
            name: request.name,
            city: request.city,
            country: request.country,
            latitude: request.latitude,
            longitude: request.longitude
        )

        let response: [VenueResponseDTO] = try await supabaseClient.upsertRows(
            into: "venues",
            payload: payload,
            onConflict: "id",
            decoder: decoder
        )

        guard let first = response.first else {
            throw APIError.invalidResponse
        }

        return SyncResult(updatedAt: first.updatedAt)
    }

    func deleteVenue(venueId: UUID) async throws {
        let client = try await clientProvider.authorizedClient()
        guard let supabaseClient = client as? SupabaseClient else {
            throw APIError.unsupportedClient
        }

        _ = try await supabaseClient
            .from("venues")
            .delete()
            .eq("id", value: venueId.uuidString)
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

/// DTO for fetching venues from Supabase
private struct VenueRowDTO: Decodable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case city
        case country
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// DTO for upserting venues to Supabase
private struct VenueUpsertDTO: Encodable, Sendable {
    let id: UUID
    let ownerId: UUID
    let name: String
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case city
        case country
        case latitude
        case longitude
    }
}

/// DTO for venue response after upsert
private struct VenueResponseDTO: Decodable, Sendable {
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
    }
}
