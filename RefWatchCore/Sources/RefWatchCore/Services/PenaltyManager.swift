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
    private(set) public var initialRounds: Int // typically 5; configurable

    // MARK: - Lifecycle
    private(set) public var isActive: Bool = false
    private(set) public var isDecided: Bool = false
    private(set) public var winner: TeamSide? = nil

    // MARK: - First Kicker
    private(set) public var firstKicker: TeamSide = .home
    private(set) public var hasChosenFirstKicker: Bool = false

    // MARK: - Tallies and Results
    private(set) public var homeTaken: Int = 0
    private(set) public var homeScored: Int = 0
    private(set) public var homeResults: [PenaltyAttemptDetails.Result] = []
    private(set) public var homeAttempts: [PenaltyAttemptDetails] = []

    private(set) public var awayTaken: Int = 0
    private(set) public var awayScored: Int = 0
    private(set) public var awayResults: [PenaltyAttemptDetails.Result] = []
    private(set) public var awayAttempts: [PenaltyAttemptDetails] = []

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
        max(initialRounds, max(homeResults.count, awayResults.count))
    }

    public var nextTeam: TeamSide {
        if homeTaken == awayTaken { return firstKicker }
        return homeTaken < awayTaken ? .home : .away
    }

    public var isSuddenDeathActive: Bool {
        homeTaken >= initialRounds && awayTaken >= initialRounds
    }

    public func begin() {
        guard !isActive else { return }
        resetInternal()
        isActive = true
        onStart?()
    }

    public func setFirstKicker(_ team: TeamSide) {
        firstKicker = team
        hasChosenFirstKicker = true
    }

    public func markHasChosenFirstKicker(_ chosen: Bool) {
        hasChosenFirstKicker = chosen
    }

    public func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
        guard isActive else { return }
        let round = (team == .home ? homeTaken : awayTaken) + 1
        let details = PenaltyAttemptDetails(result: result, playerNumber: playerNumber, round: round)
        onAttempt?(team, details)

        if team == .home {
            homeTaken += 1
            if result == .scored { homeScored += 1 }
            homeResults.append(result)
            homeAttempts.append(details)
        } else {
            awayTaken += 1
            if result == .scored { awayScored += 1 }
            awayResults.append(result)
            awayAttempts.append(details)
        }

        computeDecisionIfNeeded()
    }

    @discardableResult
    public func undoLastAttempt() -> PenaltyUndoResult? {
        guard isActive else { return nil }
        guard homeTaken > 0 || awayTaken > 0 else { return nil }

        let lastTeam: TeamSide
        if homeTaken > awayTaken {
            lastTeam = .home
        } else if awayTaken > homeTaken {
            lastTeam = .away
        } else {
            guard homeTaken > 0 else { return nil }
            lastTeam = firstKicker == .home ? .away : .home
        }

        let undoneDetails: PenaltyAttemptDetails

        switch lastTeam {
        case .home:
            guard homeTaken > 0, let details = homeAttempts.popLast(), let _ = homeResults.popLast() else { return nil }
            homeTaken -= 1
            if details.result == .scored { homeScored = max(0, homeScored - 1) }
            undoneDetails = details
        case .away:
            guard awayTaken > 0, let details = awayAttempts.popLast(), let _ = awayResults.popLast() else { return nil }
            awayTaken -= 1
            if details.result == .scored { awayScored = max(0, awayScored - 1) }
            undoneDetails = details
        }

        computeDecisionIfNeeded()
        if !isDecided { didPlayDecisionHaptic = false }

        return PenaltyUndoResult(team: lastTeam, details: undoneDetails)
    }

    public func swapKickingOrder() {
        guard isActive else { return }
        firstKicker = firstKicker == .home ? .away : .home
        hasChosenFirstKicker = true
    }

    public func end() {
        guard isActive else { return }
        onEnd?()
        isActive = false
    }

    // MARK: - Internal
    private var didPlayDecisionHaptic: Bool = false

    private func resetInternal() {
        isDecided = false
        winner = nil
        didPlayDecisionHaptic = false
        hasChosenFirstKicker = false
        firstKicker = .home
        homeTaken = 0; homeScored = 0; homeResults.removeAll(); homeAttempts.removeAll()
        awayTaken = 0; awayScored = 0; awayResults.removeAll(); awayAttempts.removeAll()
    }

    private func computeDecisionIfNeeded() {
        // Early decision before completing initial rounds
        let homeRem = max(0, initialRounds - homeTaken)
        let awayRem = max(0, initialRounds - awayTaken)

        if homeTaken <= initialRounds || awayTaken <= initialRounds {
            if homeScored > awayScored + awayRem { decide(.home); return }
            if awayScored > homeScored + homeRem { decide(.away); return }
        }

        // Sudden death: after both reached initialRounds and attempts are equal
        if homeTaken >= initialRounds && awayTaken >= initialRounds && homeTaken == awayTaken {
            if homeScored != awayScored { decide(homeScored > awayScored ? .home : .away); return }
        }

        isDecided = false
        winner = nil
    }

    private func decide(_ team: TeamSide) {
        isDecided = true
        winner = team
        if !didPlayDecisionHaptic {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.success)
            #endif
            didPlayDecisionHaptic = true
        }
        onDecided?(team)
    }
}
