//
//  Match.swift
//  RefereeAssistant
//
//  Description: Data model representing a football/soccer match with all necessary match details and settings.
//

import Foundation

struct Match: Identifiable, Codable {
    let id: UUID
    var homeTeam: String
    var awayTeam: String
    var startTime: Date?
    var duration: TimeInterval  // In seconds
    var numberOfPeriods: Int
    var halfTimeLength: TimeInterval  // In seconds
    var extraTimeHalfLength: TimeInterval // In seconds (per ET half)
    var hasExtraTime: Bool
    var hasPenalties: Bool
    
    // Match statistics
    var homeScore: Int
    var awayScore: Int
    var homeYellowCards: Int
    var awayYellowCards: Int
    var homeRedCards: Int
    var awayRedCards: Int
    var homeSubs: Int
    var awaySubs: Int
    
    init(
        id: UUID = UUID(),
        homeTeam: String = "HOM",
        awayTeam: String = "AWA",
        duration: TimeInterval = 90 * 60,
        numberOfPeriods: Int = 2,
        halfTimeLength: TimeInterval = 15 * 60,
        extraTimeHalfLength: TimeInterval = 15 * 60,
        hasExtraTime: Bool = false,
        hasPenalties: Bool = false
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.startTime = nil
        self.duration = duration
        self.numberOfPeriods = numberOfPeriods
        self.halfTimeLength = halfTimeLength
        self.extraTimeHalfLength = extraTimeHalfLength
        self.hasExtraTime = hasExtraTime
        self.hasPenalties = hasPenalties
        
        // Initialize statistics
        self.homeScore = 0
        self.awayScore = 0
        self.homeYellowCards = 0
        self.awayYellowCards = 0
        self.homeRedCards = 0
        self.awayRedCards = 0
        self.homeSubs = 0
        self.awaySubs = 0
    }
}
