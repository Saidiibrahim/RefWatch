//
//  Venue.swift
//  RefZoneiOS
//
//  Domain model for venues/stadiums/facilities.
//  Venues track where matches are played.
//

import Foundation

/// Domain model representing a venue or stadium
struct Venue: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier
    let id: UUID

    /// Venue name (e.g., "Wembley Stadium", "City Sports Complex")
    var name: String

    /// City where venue is located (optional)
    var city: String?

    /// Country where venue is located (optional)
    var country: String?

    /// Latitude coordinate for map integration (optional)
    var latitude: Double?

    /// Longitude coordinate for map integration (optional)
    var longitude: Double?

    /// Supabase user ID who owns this venue
    var ownerId: String

    /// When the venue was created
    var createdAt: Date

    /// When the venue was last updated
    var updatedAt: Date

    /// Initialize a new venue
    init(
        id: UUID = UUID(),
        name: String,
        city: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        ownerId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Conversion Helpers

extension Venue {
    /// Create a Venue from a VenueRecord (SwiftData persistence model)
    init(from record: VenueRecord) {
        self.init(
            id: record.id,
            name: record.name,
            city: record.city,
            country: record.country,
            latitude: record.latitude,
            longitude: record.longitude,
            ownerId: record.ownerSupabaseId ?? "",
            createdAt: record.lastModifiedAt,
            updatedAt: record.remoteUpdatedAt ?? record.lastModifiedAt
        )
    }
}