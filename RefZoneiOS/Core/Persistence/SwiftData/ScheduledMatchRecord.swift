//
//  ScheduledMatchRecord.swift
//  RefZoneiOS
//
//  SwiftData model for upcoming/today scheduled matches.
//  Stores team names redundantly to remain robust if linked teams are deleted.
//

import Foundation
import SwiftData

@Model
final class ScheduledMatchRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kickoff: Date

    // Linked teams (optional)
    var homeTeam: TeamRecord?
    var awayTeam: TeamRecord?

    // Denormalized names for resilience and fast listing
    var homeName: String
    var awayName: String

    var competition: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kickoff: Date,
        homeTeam: TeamRecord? = nil,
        awayTeam: TeamRecord? = nil,
        homeName: String,
        awayName: String,
        competition: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kickoff = kickoff
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeName = homeName
        self.awayName = awayName
        self.competition = competition
        self.notes = notes
    }
}

