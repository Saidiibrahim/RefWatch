//
//  PenaltyManager.swift
//  RefWatch Watch App
//
//  Description: Focused service managing penalty shootout logic: sequencing,
//  tallies, decision state, and haptic on decision. Designed for SRP and tests.
//

import Foundation
import Observation
import WatchKit

@Observable
final class PenaltyManager: PenaltyManaging {
    // MARK: - Configuration
    private(set) var initialRounds: Int // typically 5; configurable

    // MARK: - Lifecycle
    private(set) var isActive: Bool = false
    private(set) var isDecided: Bool = false
    private(set) var winner: TeamSide? = nil

    // MARK: - First Kicker
    private(set) var firstKicker: TeamSide = .home
    private(set) var hasChosenFirstKicker: Bool = false

    // MARK: - Tallies and Results
    private(set) var homeTaken: Int = 0
    private(set) var homeScored: Int = 0
    private(set) var homeResults: [PenaltyAttemptDetails.Result] = []

    private(set) var awayTaken: Int = 0
    private(set) var awayScored: Int = 0
    private(set) var awayResults: [PenaltyAttemptDetails.Result] = []

    // MARK: - Callbacks (wired by VM)
    var onStart: (() -> Void)?
    var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)?
    var onDecided: ((TeamSide) -> Void)?
    var onEnd: (() -> Void)?

    // MARK: - Init
    init(initialRounds: Int = 5) {
        self.initialRounds = max(1, initialRounds)
    }

    // MARK: - Public API

    func setInitialRounds(_ rounds: Int) {
        self.initialRounds = max(1, rounds)
    }

    var roundsVisible: Int {
        max(initialRounds, max(homeResults.count, awayResults.count))
    }

    var nextTeam: TeamSide {
        if homeTaken == awayTaken { return firstKicker }
        return homeTaken < awayTaken ? .home : .away
    }

    var isSuddenDeathActive: Bool {
        homeTaken >= initialRounds && awayTaken >= initialRounds
    }

    func begin() {
        guard !isActive else { return }
        resetInternal()
        isActive = true
        onStart?()
    }

    func setFirstKicker(_ team: TeamSide) {
        firstKicker = team
        hasChosenFirstKicker = true
    }

    func markHasChosenFirstKicker(_ chosen: Bool) {
        hasChosenFirstKicker = chosen
    }

    func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
        guard isActive else { return }
        let round = (team == .home ? homeTaken : awayTaken) + 1
        let details = PenaltyAttemptDetails(result: result, playerNumber: playerNumber, round: round)
        onAttempt?(team, details)

        if team == .home {
            homeTaken += 1
            if result == .scored { homeScored += 1 }
            homeResults.append(result)
        } else {
            awayTaken += 1
            if result == .scored { awayScored += 1 }
            awayResults.append(result)
        }

        computeDecisionIfNeeded()
    }

    func end() {
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
        homeTaken = 0; homeScored = 0; homeResults.removeAll()
        awayTaken = 0; awayScored = 0; awayResults.removeAll()
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
            WKInterfaceDevice.current().play(.success)
            didPlayDecisionHaptic = true
        }
        onDecided?(team)
    }
}
