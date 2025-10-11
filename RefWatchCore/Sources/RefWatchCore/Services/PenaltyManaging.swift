//
//  PenaltyManaging.swift
//  RefWatchCore
//
//  Protocol abstraction for PenaltyManager to enable testing and
//  controlled simulation of edge cases (e.g., begin() failure paths).
//

import Foundation

public struct PenaltyUndoResult {
    public let team: TeamSide
    public let details: PenaltyAttemptDetails

    public init(team: TeamSide, details: PenaltyAttemptDetails) {
        self.team = team
        self.details = details
    }
}

public protocol PenaltyManaging: AnyObject {
    // Observables / State
    var isActive: Bool { get }
    var isDecided: Bool { get }
    var winner: TeamSide? { get }

    var firstKicker: TeamSide { get }
    var hasChosenFirstKicker: Bool { get }

    var homeTaken: Int { get }
    var homeScored: Int { get }
    var homeResults: [PenaltyAttemptDetails.Result] { get }
    var awayTaken: Int { get }
    var awayScored: Int { get }
    var awayResults: [PenaltyAttemptDetails.Result] { get }

    var roundsVisible: Int { get }
    var nextTeam: TeamSide { get }
    var isSuddenDeathActive: Bool { get }

    // Lifecycle
    func setInitialRounds(_ rounds: Int)
    func begin()
    func setFirstKicker(_ team: TeamSide)
    func markHasChosenFirstKicker(_ chosen: Bool)
    func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int?)
    func undoLastAttempt() -> PenaltyUndoResult?
    func swapKickingOrder()
    func end()

    // Event callbacks
    var onStart: (() -> Void)? { get set }
    var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)? { get set }
    var onDecided: ((TeamSide) -> Void)? { get set }
    var onEnd: (() -> Void)? { get set }
}
