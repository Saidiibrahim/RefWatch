//
//  ActiveMatchSessionSnapshot.swift
//  RefWatchCore
//
//  Description: Codable unfinished-match snapshot types used to reopen Match
//  Mode on the correct screen after interruption or relaunch.
//

import Foundation

/// Display strings captured alongside an unfinished match so the watch can
/// restore the last visible timer state before live timers resume.
public struct ActiveMatchDisplayState: Codable, Equatable {
  public var matchTime: String
  public var periodTime: String
  public var periodTimeRemaining: String
  public var halfTimeRemaining: String
  public var halfTimeElapsed: String
  public var formattedStoppageTime: String

  public init(
    matchTime: String,
    periodTime: String,
    periodTimeRemaining: String,
    halfTimeRemaining: String,
    halfTimeElapsed: String,
    formattedStoppageTime: String)
  {
    self.matchTime = matchTime
    self.periodTime = periodTime
    self.periodTimeRemaining = periodTimeRemaining
    self.halfTimeRemaining = halfTimeRemaining
    self.halfTimeElapsed = halfTimeElapsed
    self.formattedStoppageTime = formattedStoppageTime
  }
}

/// Complete persistence payload for an unfinished match session.
///
/// The snapshot records every lifecycle flag needed to reopen Match Mode on the
/// correct screen after watchOS interruption, relaunch, or active workout
/// recovery.
public struct ActiveMatchSessionSnapshot: Codable {
  public static let schemaVersion = 1

  public var schemaVersion: Int
  public var match: Match
  public var currentPeriod: Int
  public var isMatchInProgress: Bool
  public var isHalfTime: Bool
  public var isPaused: Bool
  public var waitingForMatchStart: Bool
  public var waitingForHalfTimeStart: Bool
  public var waitingForSecondHalfStart: Bool
  public var waitingForET1Start: Bool
  public var waitingForET2Start: Bool
  public var waitingForPenaltiesStart: Bool
  public var isFullTime: Bool
  public var matchCompleted: Bool
  public var displayState: ActiveMatchDisplayState
  public var isInStoppage: Bool
  public var homeTeamKickingOff: Bool
  public var homeTeamKickingOffET1: Bool?
  public var matchEvents: [MatchEventRecord]
  public var penaltyState: PenaltyShootoutSnapshot
  public var timerState: TimerManager.PersistenceState
  public var penaltyStartEventLogged: Bool
  public var savedAt: Date

  public init(
    schemaVersion: Int = ActiveMatchSessionSnapshot.schemaVersion,
    match: Match,
    currentPeriod: Int,
    isMatchInProgress: Bool,
    isHalfTime: Bool,
    isPaused: Bool,
    waitingForMatchStart: Bool,
    waitingForHalfTimeStart: Bool,
    waitingForSecondHalfStart: Bool,
    waitingForET1Start: Bool,
    waitingForET2Start: Bool,
    waitingForPenaltiesStart: Bool,
    isFullTime: Bool,
    matchCompleted: Bool,
    displayState: ActiveMatchDisplayState,
    isInStoppage: Bool,
    homeTeamKickingOff: Bool,
    homeTeamKickingOffET1: Bool?,
    matchEvents: [MatchEventRecord],
    penaltyState: PenaltyShootoutSnapshot,
    timerState: TimerManager.PersistenceState,
    penaltyStartEventLogged: Bool,
    savedAt: Date = Date())
  {
    self.schemaVersion = schemaVersion
    self.match = match
    self.currentPeriod = currentPeriod
    self.isMatchInProgress = isMatchInProgress
    self.isHalfTime = isHalfTime
    self.isPaused = isPaused
    self.waitingForMatchStart = waitingForMatchStart
    self.waitingForHalfTimeStart = waitingForHalfTimeStart
    self.waitingForSecondHalfStart = waitingForSecondHalfStart
    self.waitingForET1Start = waitingForET1Start
    self.waitingForET2Start = waitingForET2Start
    self.waitingForPenaltiesStart = waitingForPenaltiesStart
    self.isFullTime = isFullTime
    self.matchCompleted = matchCompleted
    self.displayState = displayState
    self.isInStoppage = isInStoppage
    self.homeTeamKickingOff = homeTeamKickingOff
    self.homeTeamKickingOffET1 = homeTeamKickingOffET1
    self.matchEvents = matchEvents
    self.penaltyState = penaltyState
    self.timerState = timerState
    self.penaltyStartEventLogged = penaltyStartEventLogged
    self.savedAt = savedAt
  }

  /// Indicates whether the snapshot still represents a match that should be
  /// restorable into Match Mode.
  public var isUnfinished: Bool {
    self.matchCompleted == false
  }
}

/// Persistence boundary for storing and loading unfinished-match snapshots.
@MainActor
public protocol ActiveMatchSessionStoring: AnyObject {
  func load() throws -> ActiveMatchSessionSnapshot?
  func save(_ snapshot: ActiveMatchSessionSnapshot) throws
  func clear() throws
}

/// Store implementation used when the host surface does not support unfinished
/// match persistence.
@MainActor
public final class NoopActiveMatchSessionStore: ActiveMatchSessionStoring {
  public init() {}

  public func load() throws -> ActiveMatchSessionSnapshot? {
    nil
  }

  public func save(_ snapshot: ActiveMatchSessionSnapshot) throws {}

  public func clear() throws {}
}
