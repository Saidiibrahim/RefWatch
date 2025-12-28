//
//  Competition.swift
//  RefWatchiOS
//
//  Domain model for competitions/tournaments.
//  Competitions group matches together (e.g., "Premier League", "Champions League").
//

import Foundation

/// Domain model representing a competition or tournament
struct Competition: Identifiable, Codable, Hashable, Sendable {
    /// Unique identifier
    let id: UUID

    /// Competition name (e.g., "Premier League")
    var name: String

    /// Competition level/tier (e.g., "Professional", "Amateur", "Youth")
    var level: String?

    /// Supabase user ID who owns this competition
    var ownerId: String

    /// When the competition was created
    var createdAt: Date

    /// When the competition was last updated
    var updatedAt: Date

    /// Initialize a new competition
    init(
        id: UUID = UUID(),
        name: String,
        level: String? = nil,
        ownerId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Conversion Helpers

extension Competition {
    /// Create a Competition from a CompetitionRecord (SwiftData persistence model)
    init(from record: CompetitionRecord) {
        self.init(
            id: record.id,
            name: record.name,
            level: record.level,
            ownerId: record.ownerSupabaseId ?? "",
            createdAt: record.lastModifiedAt,
            updatedAt: record.remoteUpdatedAt ?? record.lastModifiedAt
        )
    }
}