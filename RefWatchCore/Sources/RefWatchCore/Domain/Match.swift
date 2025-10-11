//
//  Match.swift
//  RefWatchCore
//
//  Data model representing a football/soccer match with configuration
//  and tallies. Shared across watchOS and iOS.
//

import Foundation

public struct Match: Identifiable, Codable {
    public let id: UUID
    public var homeTeam: String
    public var awayTeam: String
    public var homeTeamId: UUID?
    public var awayTeamId: UUID?
    public var competitionId: UUID?
    public var competitionName: String?
    public var venueId: UUID?
    public var venueName: String?
    public var startTime: Date?
    public var duration: TimeInterval  // In seconds
    public var numberOfPeriods: Int
    public var halfTimeLength: TimeInterval  // In seconds
    public var extraTimeHalfLength: TimeInterval // In seconds (per ET half)
    public var hasExtraTime: Bool
    public var hasPenalties: Bool
    public var penaltyInitialRounds: Int
    
    // Match statistics
    public var homeScore: Int
    public var awayScore: Int
    public var homeYellowCards: Int
    public var awayYellowCards: Int
    public var homeRedCards: Int
    public var awayRedCards: Int
    public var homeSubs: Int
    public var awaySubs: Int
    
    public init(
        id: UUID = UUID(),
        homeTeam: String = "HOM",
        awayTeam: String = "AWA",
        duration: TimeInterval = 90 * 60,
        numberOfPeriods: Int = 2,
        halfTimeLength: TimeInterval = 15 * 60,
        extraTimeHalfLength: TimeInterval = 15 * 60,
        hasExtraTime: Bool = false,
        hasPenalties: Bool = false,
        penaltyInitialRounds: Int = 5,
        homeTeamId: UUID? = nil,
        awayTeamId: UUID? = nil,
        competitionId: UUID? = nil,
        competitionName: String? = nil,
        venueId: UUID? = nil,
        venueName: String? = nil
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.competitionId = competitionId
        self.competitionName = competitionName
        self.venueId = venueId
        self.venueName = venueName
        self.startTime = nil
        self.duration = duration
        self.numberOfPeriods = numberOfPeriods
        self.halfTimeLength = halfTimeLength
        self.extraTimeHalfLength = extraTimeHalfLength
        self.hasExtraTime = hasExtraTime
        self.hasPenalties = hasPenalties
        self.penaltyInitialRounds = max(1, penaltyInitialRounds)
        
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
