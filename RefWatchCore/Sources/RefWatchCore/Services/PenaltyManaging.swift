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

public struct PenaltyShootoutSnapshot: Codable, Equatable {
    public var initialRounds: Int
    public var isActive: Bool
    public var isDecided: Bool
    public var winner: TeamSide?
    public var firstKicker: TeamSide
    public var hasChosenFirstKicker: Bool
    public var homeTaken: Int
    public var homeScored: Int
    public var homeResults: [PenaltyAttemptDetails.Result]
    public var homeAttempts: [PenaltyAttemptDetails]
    public var awayTaken: Int
    public var awayScored: Int
    public var awayResults: [PenaltyAttemptDetails.Result]
    public var awayAttempts: [PenaltyAttemptDetails]
    public var attemptStack: [TeamSide]

    public init(
        initialRounds: Int = 5,
        isActive: Bool = false,
        isDecided: Bool = false,
        winner: TeamSide? = nil,
        firstKicker: TeamSide = .home,
        hasChosenFirstKicker: Bool = false,
        homeTaken: Int = 0,
        homeScored: Int = 0,
        homeResults: [PenaltyAttemptDetails.Result] = [],
        homeAttempts: [PenaltyAttemptDetails] = [],
        awayTaken: Int = 0,
        awayScored: Int = 0,
        awayResults: [PenaltyAttemptDetails.Result] = [],
        awayAttempts: [PenaltyAttemptDetails] = [],
        attemptStack: [TeamSide] = []
    ) {
        self.initialRounds = initialRounds
        self.isActive = isActive
        self.isDecided = isDecided
        self.winner = winner
        self.firstKicker = firstKicker
        self.hasChosenFirstKicker = hasChosenFirstKicker
        self.homeTaken = homeTaken
        self.homeScored = homeScored
        self.homeResults = homeResults
        self.homeAttempts = homeAttempts
        self.awayTaken = awayTaken
        self.awayScored = awayScored
        self.awayResults = awayResults
        self.awayAttempts = awayAttempts
        self.attemptStack = attemptStack
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
    func snapshotState() -> PenaltyShootoutSnapshot
    func restore(from snapshot: PenaltyShootoutSnapshot)

    // Event callbacks
    var onStart: (() -> Void)? { get set }
    var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)? { get set }
    var onDecided: ((TeamSide) -> Void)? { get set }
    var onEnd: (() -> Void)? { get set }
}
