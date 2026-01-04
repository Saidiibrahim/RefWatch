//
//  PenaltyManager.swift
//  RefWatchCore
//
//  Focused service managing penalty shootout logic: sequencing,
//  tallies, decision state, and haptic on decision. Designed for SRP and tests.
//

import Foundation
import Observation
#if os(watchOS)
import WatchKit
#endif

@Observable
public final class PenaltyManager: PenaltyManaging {
  // MARK: - Configuration

  public private(set) var initialRounds: Int // typically 5; configurable

  // MARK: - Lifecycle

  public private(set) var isActive: Bool = false
  public private(set) var isDecided: Bool = false
  public private(set) var winner: TeamSide?

  // MARK: - First Kicker

  public private(set) var firstKicker: TeamSide = .home
  public private(set) var hasChosenFirstKicker: Bool = false

  // MARK: - Tallies and Results

  public private(set) var homeTaken: Int = 0
  public private(set) var homeScored: Int = 0
  public private(set) var homeResults: [PenaltyAttemptDetails.Result] = []
  public private(set) var homeAttempts: [PenaltyAttemptDetails] = []

  public private(set) var awayTaken: Int = 0
  public private(set) var awayScored: Int = 0
  public private(set) var awayResults: [PenaltyAttemptDetails.Result] = []
  public private(set) var awayAttempts: [PenaltyAttemptDetails] = []

  /// Tracks the actual order attempts were recorded so undo remains reliable even if
  /// first-kicker swaps after play has started.
  private var attemptStack: [TeamSide] = []

  // MARK: - Callbacks (wired by VM)

  public var onStart: (() -> Void)?
  public var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)?
  public var onDecided: ((TeamSide) -> Void)?
  public var onEnd: (() -> Void)?

  // MARK: - Init

  public init(initialRounds: Int = 5) {
    self.initialRounds = max(1, initialRounds)
  }

  // MARK: - Public API

  public func setInitialRounds(_ rounds: Int) {
    self.initialRounds = max(1, rounds)
  }

  public var roundsVisible: Int {
    max(self.initialRounds, max(self.homeResults.count, self.awayResults.count))
  }

  public var nextTeam: TeamSide {
    if self.homeTaken == self.awayTaken { return self.firstKicker }
    return self.homeTaken < self.awayTaken ? .home : .away
  }

  public var isSuddenDeathActive: Bool {
    self.homeTaken >= self.initialRounds && self.awayTaken >= self.initialRounds
  }

  public func begin() {
    guard !self.isActive else { return }
    self.resetInternal()
    self.isActive = true
    self.onStart?()
  }

  public func setFirstKicker(_ team: TeamSide) {
    self.firstKicker = team
    self.hasChosenFirstKicker = true
  }

  public func markHasChosenFirstKicker(_ chosen: Bool) {
    self.hasChosenFirstKicker = chosen
  }

  public func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
    guard self.isActive else { return }
    let round = (team == .home ? self.homeTaken : self.awayTaken) + 1
    let details = PenaltyAttemptDetails(result: result, playerNumber: playerNumber, round: round)
    self.onAttempt?(team, details)

    if team == .home {
      self.homeTaken += 1
      if result == .scored { self.homeScored += 1 }
      self.homeResults.append(result)
      self.homeAttempts.append(details)
    } else {
      self.awayTaken += 1
      if result == .scored { self.awayScored += 1 }
      self.awayResults.append(result)
      self.awayAttempts.append(details)
    }

    self.attemptStack.append(team)
    self.computeDecisionIfNeeded()
  }

  @discardableResult
  public func undoLastAttempt() -> PenaltyUndoResult? {
    guard self.isActive else { return nil }
    guard self.homeTaken > 0 || self.awayTaken > 0 else { return nil }

    guard let lastTeam = attemptStack.popLast() else { return nil }

    let undoneDetails: PenaltyAttemptDetails

    switch lastTeam {
    case .home:
      guard self.homeTaken > 0,
            let details = homeAttempts.popLast(),
            homeResults.popLast() != nil
      else { return nil }
      self.homeTaken -= 1
      if details.result == .scored { self.homeScored = max(0, self.homeScored - 1) }
      undoneDetails = details
    case .away:
      guard self.awayTaken > 0,
            let details = awayAttempts.popLast(),
            awayResults.popLast() != nil
      else { return nil }
      self.awayTaken -= 1
      if details.result == .scored { self.awayScored = max(0, self.awayScored - 1) }
      undoneDetails = details
    }

    self.computeDecisionIfNeeded()
    if !self.isDecided { self.didPlayDecisionHaptic = false }

    return PenaltyUndoResult(team: lastTeam, details: undoneDetails)
  }

  public func swapKickingOrder() {
    guard self.isActive else { return }
    self.firstKicker = self.firstKicker == .home ? .away : .home
    self.hasChosenFirstKicker = true
  }

  public func end() {
    guard self.isActive else { return }
    self.onEnd?()
    self.isActive = false
  }

  // MARK: - Internal

  private var didPlayDecisionHaptic: Bool = false

  private func resetInternal() {
    self.isDecided = false
    self.winner = nil
    self.didPlayDecisionHaptic = false
    self.hasChosenFirstKicker = false
    self.firstKicker = .home
    self.homeTaken = 0; self.homeScored = 0; self.homeResults.removeAll(); self.homeAttempts.removeAll()
    self.awayTaken = 0; self.awayScored = 0; self.awayResults.removeAll(); self.awayAttempts.removeAll()
    self.attemptStack.removeAll()
  }

  private func computeDecisionIfNeeded() {
    // Early decision before completing initial rounds: decide as soon as the trailing
    // side's maximum possible score (remaining kicks + current goals) can no longer
    // catch the leader.
    let homeRem = max(0, initialRounds - self.homeTaken)
    let awayRem = max(0, initialRounds - self.awayTaken)

    if self.homeTaken <= self.initialRounds || self.awayTaken <= self.initialRounds {
      if self.homeScored > self.awayScored + awayRem { self.decide(.home); return }
      if self.awayScored > self.homeScored + homeRem { self.decide(.away); return }
    }

    // Sudden death: after both reached initialRounds and attempts are equal
    if self.homeTaken >= self.initialRounds, self.awayTaken >= self.initialRounds, self.homeTaken == self.awayTaken {
      if self.homeScored != self.awayScored { self.decide(self.homeScored > self.awayScored ? .home : .away); return }
    }

    self.isDecided = false
    self.winner = nil
  }

  private func decide(_ team: TeamSide) {
    self.isDecided = true
    self.winner = team
    if !self.didPlayDecisionHaptic {
      #if os(watchOS)
      WKInterfaceDevice.current().play(.success)
      #endif
      self.didPlayDecisionHaptic = true
    }
    self.onDecided?(team)
  }
}
