//
//  CompletedMatchRecord.swift
//  RefZoneiOS
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

    // Full snapshot retained as encoded JSON for fidelity
    var payload: Data

    init(
        id: UUID,
        completedAt: Date,
        ownerId: String?,
        homeTeam: String,
        awayTeam: String,
        homeScore: Int,
        awayScore: Int,
        payload: Data
    ) {
        self.id = id
        self.completedAt = completedAt
        self.ownerId = ownerId
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.payload = payload
    }
}
