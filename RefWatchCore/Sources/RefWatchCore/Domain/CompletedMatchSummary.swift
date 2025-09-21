//
//  CompletedMatchSummary.swift
//  RefWatchCore
//
//  Lightweight summary metadata extracted from a completed match.
//

import Foundation

public struct CompletedMatchSummary: Sendable, Equatable {
    public let homeTeam: String
    public let awayTeam: String
    public let homeScore: Int
    public let awayScore: Int
    public let completedAt: Date
    public let regulationMinutes: Int
    public let totalCards: Int
    public let totalSubs: Int
    public let totalGoals: Int

    public init(match: CompletedMatch) {
        homeTeam = match.match.homeTeam
        awayTeam = match.match.awayTeam
        homeScore = match.match.homeScore
        awayScore = match.match.awayScore
        completedAt = match.completedAt
        regulationMinutes = Int((max(0, match.match.duration) / 60).rounded())
        totalCards = match.match.homeYellowCards + match.match.homeRedCards + match.match.awayYellowCards + match.match.awayRedCards
        totalSubs = match.match.homeSubs + match.match.awaySubs
        totalGoals = match.match.homeScore + match.match.awayScore
    }

    public var headline: String { "\(homeTeam) vs \(awayTeam)" }
    public var scoreline: String { "\(homeScore) – \(awayScore)" }
}
