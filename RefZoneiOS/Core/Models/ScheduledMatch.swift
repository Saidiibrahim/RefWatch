//
//  ScheduledMatch.swift
//  RefZoneiOS
//
//  Lightweight model for upcoming/today matches shown in the Matches tab.
//

import Foundation

struct ScheduledMatch: Identifiable, Codable, Hashable {
    let id: UUID
    var homeTeam: String
    var awayTeam: String
    var kickoff: Date

    init(id: UUID = UUID(), homeTeam: String, awayTeam: String, kickoff: Date) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.kickoff = kickoff
    }
}
