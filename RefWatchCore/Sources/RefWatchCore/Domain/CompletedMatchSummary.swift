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
    self.homeTeam = match.match.homeTeam
    self.awayTeam = match.match.awayTeam
    self.homeScore = match.match.homeScore
    self.awayScore = match.match.awayScore
    self.completedAt = match.completedAt
    self.regulationMinutes = Int((max(0, match.match.duration) / 60).rounded())
    self.totalCards =
      match.match.homeYellowCards
        + match.match.homeRedCards
        + match.match.awayYellowCards
        + match.match.awayRedCards
    self.totalSubs = match.match.homeSubs + match.match.awaySubs
    self.totalGoals = match.match.homeScore + match.match.awayScore
  }

  public var headline: String { "\(self.homeTeam) vs \(self.awayTeam)" }
  public var scoreline: String { "\(self.homeScore) – \(self.awayScore)" }
}
