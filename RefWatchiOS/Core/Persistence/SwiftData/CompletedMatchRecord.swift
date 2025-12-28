//
//  CompletedMatchRecord.swift
//  RefWatchiOS
//
//  SwiftData model for storing CompletedMatch snapshots on iOS.
//

import Foundation
import SwiftData

@Model
final class CompletedMatchRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var ownerId: String?

    // Lightweight indexing fields for lists
    var homeTeam: String
    var awayTeam: String
    var homeScore: Int
    var awayScore: Int
    var homeTeamId: UUID?
    var awayTeamId: UUID?
    var competitionId: UUID?
    var competitionName: String?
    var venueId: UUID?
    var venueName: String?

    // Full snapshot retained as encoded JSON for fidelity
    var payload: Data

    // Supabase metadata
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool
    var lastSyncedAt: Date?
    var sourceDeviceId: String?

    init(
        id: UUID,
        completedAt: Date,
        ownerId: String?,
        homeTeam: String,
        awayTeam: String,
        homeScore: Int,
        awayScore: Int,
        homeTeamId: UUID? = nil,
        awayTeamId: UUID? = nil,
        competitionId: UUID? = nil,
        competitionName: String? = nil,
        venueId: UUID? = nil,
        venueName: String? = nil,
        payload: Data,
        remoteUpdatedAt: Date? = nil,
        needsRemoteSync: Bool = false,
        lastSyncedAt: Date? = nil,
        sourceDeviceId: String? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.ownerId = ownerId
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.competitionId = competitionId
        self.competitionName = competitionName
        self.venueId = venueId
        self.venueName = venueName
        self.payload = payload
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
        self.lastSyncedAt = lastSyncedAt
        self.sourceDeviceId = sourceDeviceId
    }
}
