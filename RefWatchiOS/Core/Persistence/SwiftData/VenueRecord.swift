//
//  VenueRecord.swift
//  RefWatchiOS
//
//  SwiftData persistence model for venues.
//  Tracks local state and sync metadata for Supabase integration.
//

import Foundation
import SwiftData

/// SwiftData model for persisting venues locally with sync metadata
@Model
final class VenueRecord {
    /// Unique identifier (matches Supabase venue.id)
    @Attribute(.unique) var id: UUID

    /// Venue name
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
    var ownerSupabaseId: String?

    /// Local modification timestamp (used for conflict resolution)
    var lastModifiedAt: Date

    /// Remote updated_at timestamp from Supabase (cursor for incremental sync)
    var remoteUpdatedAt: Date?

    /// Flag indicating this record needs to be pushed to Supabase
    var needsRemoteSync: Bool

    /// Initialize a new venue record
    init(
        id: UUID,
        name: String,
        city: String?,
        country: String?,
        latitude: Double?,
        longitude: Double?,
        ownerSupabaseId: String?,
        lastModifiedAt: Date,
        remoteUpdatedAt: Date?,
        needsRemoteSync: Bool
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.ownerSupabaseId = ownerSupabaseId
        self.lastModifiedAt = lastModifiedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
    }
}