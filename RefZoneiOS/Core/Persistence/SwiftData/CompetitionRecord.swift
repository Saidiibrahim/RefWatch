//
//  CompetitionRecord.swift
//  RefZoneiOS
//
//  SwiftData persistence model for competitions.
//  Tracks local state and sync metadata for Supabase integration.
//

import Foundation
import SwiftData

/// SwiftData model for persisting competitions locally with sync metadata
@Model
final class CompetitionRecord {
    /// Unique identifier (matches Supabase competition.id)
    @Attribute(.unique) var id: UUID

    /// Competition name
    var name: String

    /// Competition level/tier (optional)
    var level: String?

    /// Supabase user ID who owns this competition
    var ownerSupabaseId: String?

    /// Local modification timestamp (used for conflict resolution)
    var lastModifiedAt: Date

    /// Remote updated_at timestamp from Supabase (cursor for incremental sync)
    var remoteUpdatedAt: Date?

    /// Flag indicating this record needs to be pushed to Supabase
    var needsRemoteSync: Bool

    /// Initialize a new competition record
    init(
        id: UUID,
        name: String,
        level: String?,
        ownerSupabaseId: String?,
        lastModifiedAt: Date,
        remoteUpdatedAt: Date?,
        needsRemoteSync: Bool
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.ownerSupabaseId = ownerSupabaseId
        self.lastModifiedAt = lastModifiedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
    }
}