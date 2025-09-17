//
//  MatchViewModel.swift
//  RefWatchCore
//
//  ViewModel controlling match timing, periods, statistics, and events.
//  UI-agnostic and shared across platforms via adapters.
//

import Foundation
import Observation

// MARK: - TimerManager Integration

@Observable
public final class MatchViewModel {
    // MARK: - Properties
    public internal(set) var currentMatch: Match?
    public private(set) var savedMatches: [Match]
    private let history: MatchHistoryStoring
    
    public var newMatch: Match
    public var isMatchInProgress: Bool = false
    public var currentPeriod: Int = 1
    public var isHalfTime: Bool = false
    public var isPaused: Bool = false
    
    // Period transition states
    public var waitingForMatchStart: Bool = true
    public var waitingForHalfTimeStart: Bool = false
    public var waitingForSecondHalfStart: Bool = false
    public var waitingForET1Start: Bool = false
    public var waitingForET2Start: Bool = false
    public var waitingForPenaltiesStart: Bool = false
    public var isFullTime: Bool = false
    public var matchCompleted: Bool = false
    
    // Timer properties (delegated)
    private let timerManager = TimerManager()
    private var timer: Timer? // legacy retained for compatibility
    private var stoppageTimer: Timer? // legacy retained for compatibility
    private var elapsedTime: TimeInterval = 0 // maintained for formattedElapsedTime
    
    // Formatted time strings
    public var matchTime: String = "00:00"
    public var periodTime: String = "00:00"
    public var periodTimeRemaining: String = "00:00"
    public var halfTimeRemaining: String = "00:00"
    public var halfTimeElapsed: String = "00:00"
    
    // Stoppage time tracking
    private var stoppageTime: TimeInterval = 0
    private var stoppageStartTime: Date?
    public var isInStoppage: Bool = false
    public var formattedStoppageTime: String = "00:00"
    
    public var formattedElapsedTime: String {
        if isMatchInProgress {
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return "00:00"
    }
    
    public var homeTeam: String = "HOM"
    public var awayTeam: String = "AWA"
    
    // Comprehensive match event tracking
    public private(set) var matchEvents: [MatchEventRecord] = []
    
    // Configuration mirrors
    public var matchDuration: Int = 90
    public var numberOfPeriods: Int = 2
    public var halfTimeLength: Int = 15
    public var hasExtraTime: Bool = false
    public var hasPenalties: Bool = false
    // Configurable extras
    public var extraTimeHalfLengthMinutes: Int = 15
    public var penaltyInitialRounds: Int = 5
    
    private(set) var homeTeamKickingOff: Bool = false
    private(set) var homeTeamKickingOffET1: Bool? = nil

    // Penalties managed by PenaltyManager (SRP); injected for testing
    private let penaltyManager: PenaltyManaging
    private let haptics: HapticsProviding
    private let connectivity: ConnectivitySyncProviding?
    
    // Persistence error feedback surfaced to UI (optional alert)
    public var lastPersistenceError: String? = nil
    
    // Computed bridges to maintain current UI/View API
    public var penaltyShootoutActive: Bool { penaltyManager.isActive }
    public var homePenaltiesScored: Int { penaltyManager.homeScored }
    public var homePenaltiesTaken: Int { penaltyManager.homeTaken }
    public var awayPenaltiesScored: Int { penaltyManager.awayScored }
    public var awayPenaltiesTaken: Int { penaltyManager.awayTaken }
    public var homePenaltyResults: [PenaltyAttemptDetails.Result] { penaltyManager.homeResults }
    public var awayPenaltyResults: [PenaltyAttemptDetails.Result] { penaltyManager.awayResults }
    public var penaltyRoundsVisible: Int { penaltyManager.roundsVisible }
    public var nextPenaltyTeam: TeamSide { penaltyManager.nextTeam }
    public var penaltyFirstKicker: TeamSide { penaltyManager.firstKicker }
    public var isPenaltyShootoutDecided: Bool { penaltyManager.isDecided }
    public var penaltyWinner: TeamSide? { penaltyManager.winner }
    public var hasChosenPenaltyFirstKicker: Bool {
        get { penaltyManager.hasChosenFirstKicker }
        set { penaltyManager.markHasChosenFirstKicker(newValue) }
    }
    public var isSuddenDeathActive: Bool { penaltyManager.isSuddenDeathActive }

    public var homeTeamDisplayName: String { currentMatch?.homeTeam ?? homeTeam }
    public var awayTeamDisplayName: String { currentMatch?.awayTeam ?? awayTeam }

    // MARK: - Initialization
    @MainActor
    public init(history: MatchHistoryStoring, penaltyManager: PenaltyManaging = PenaltyManager(), haptics: HapticsProviding = NoopHaptics(), connectivity: ConnectivitySyncProviding? = nil) {
        self.history = history
        self.penaltyManager = penaltyManager
        self.haptics = haptics
        self.connectivity = connectivity
        self.savedMatches = [
            Match(homeTeam: "Leeds United", awayTeam: "Newcastle United")
        ]
        self.newMatch = Match()
    }

    // Convenience initializers to preserve previous call sites
    @MainActor
    public convenience init(haptics: HapticsProviding = NoopHaptics()) {
        self.init(history: MatchHistoryService(), penaltyManager: PenaltyManager(), haptics: haptics, connectivity: nil)
    }

    @MainActor
    public convenience init(haptics: HapticsProviding = NoopHaptics(), connectivity: ConnectivitySyncProviding?) {
        self.init(history: MatchHistoryService(), penaltyManager: PenaltyManager(), haptics: haptics, connectivity: connectivity)
    }
    
    // MARK: - Match Management
    public func createMatch() {
        currentMatch = newMatch
        savedMatches.append(newMatch)
        newMatch = Match()
    }
    
    public func selectMatch(_ match: Match) {
        currentMatch = match
    }
    
    // MARK: - Timer Control
    public func startMatch() {
        guard let _ = currentMatch else { return }
        
        if !isMatchInProgress {
            isMatchInProgress = true
            isPaused = false
            waitingForMatchStart = false
            if var m = currentMatch {
                m.startTime = Date()
                currentMatch = m
            }
            if let match = currentMatch {
                self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
            }
            stoppageTimer?.invalidate(); stoppageTimer = nil
            timerManager.resetForNewPeriod()
            stoppageTime = 0
            stoppageStartTime = nil
            isInStoppage = false
            formattedStoppageTime = "00:00"
            
            recordMatchEvent(.kickOff)
            recordMatchEvent(.periodStart(currentPeriod))
            
            if let match = currentMatch {
                timerManager.startPeriod(
                    match: match,
                    currentPeriod: currentPeriod,
                    onTick: { [weak self] snap in
                        guard let self = self else { return }
                        self.matchTime = snap.matchTime
                        self.periodTime = snap.periodTime
                        self.periodTimeRemaining = snap.periodTimeRemaining
                        self.formattedStoppageTime = snap.formattedStoppageTime
                        self.isInStoppage = snap.isInStoppage
                    },
                    onPeriodEnd: { [weak self] in
                        self?.endPeriod()
                    }
                )
            }
        }
    }
    
    public func pauseMatch() {
        isPaused = true
        timerManager.pause { [weak self] snap in
            guard let self = self else { return }
            // Ensure the elapsed match time continues to reflect current time while paused
            self.matchTime = snap.matchTime
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
        }
    }
    
    public func resumeMatch() {
        isPaused = false
        timerManager.resume { [weak self] snap in
            guard let self = self else { return }
            self.matchTime = snap.matchTime
            self.periodTime = snap.periodTime
            self.periodTimeRemaining = snap.periodTimeRemaining
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
        }
    }

    // MARK: - Stoppage While Running (faces may use these)
    public func beginStoppage() {
        // Do not change isPaused; keep main period/elapsed timers running
        timerManager.beginStoppageWhileRunning { [weak self] snap in
            guard let self = self else { return }
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
        }
    }

    public func endStoppage() {
        timerManager.endStoppageWhileRunning { [weak self] snap in
            guard let self = self else { return }
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
        }
    }
    
    public func startNextPeriod() {
        currentPeriod += 1
        isHalfTime = false
        
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        
        recordMatchEvent(.periodStart(currentPeriod))
        
        if let match = currentMatch {
            self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
            timerManager.startPeriod(
                match: match,
                currentPeriod: currentPeriod,
                onTick: { [weak self] snap in
                    guard let self = self else { return }
                    self.matchTime = snap.matchTime
                    self.periodTime = snap.periodTime
                    self.periodTimeRemaining = snap.periodTimeRemaining
                    self.formattedStoppageTime = snap.formattedStoppageTime
                    self.isInStoppage = snap.isInStoppage
                },
                onPeriodEnd: { [weak self] in
                    self?.endPeriod()
                }
            )
        }
    }
    
    public func startHalfTime() {
        guard let match = currentMatch else { return }
        isHalfTime = true
        timerManager.startHalfTime(match: match) { [weak self] elapsed in
            self?.halfTimeElapsed = elapsed
        }
    }
    
    private func endPeriod() {
        pauseMatch()
        
        guard let match = currentMatch else { return }
        
        let total = max(1, match.numberOfPeriods)
        if currentPeriod < total {
            if currentPeriod == total / 2 {
                startHalfTime()
            }
        } else if match.hasExtraTime && currentPeriod == total {
            isMatchInProgress = false
            isPaused = false
            waitingForET1Start = true
        } else if match.hasExtraTime && currentPeriod == total + 1 {
            isMatchInProgress = false
            isPaused = false
            waitingForET2Start = true
        } else if currentPeriod == total + 2 {
            if match.hasPenalties {
                waitingForPenaltiesStart = true
            } else {
                endMatch()
            }
        } else {
            endMatch()
        }
    }
    
    private func endHalfTime() {
        endHalfTimeManually()
    }
    
    private func endMatch() {
        isMatchInProgress = false
        isFullTime = true
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
    }
    
    // MARK: - Match Statistics
    public func updateScore(isHome: Bool, increment: Bool = true) {
        guard var match = currentMatch else { return }
        if isHome { match.homeScore += increment ? 1 : -1 }
        else { match.awayScore += increment ? 1 : -1 }
        currentMatch = match
    }
    
    public func addCard(isHome: Bool, isYellow: Bool) {
        guard var match = currentMatch else { return }
        if isHome {
            if isYellow { match.homeYellowCards += 1 } else { match.homeRedCards += 1 }
        } else {
            if isYellow { match.awayYellowCards += 1 } else { match.awayRedCards += 1 }
        }
        currentMatch = match
    }
    
    public func addSubstitution(isHome: Bool) {
        guard var match = currentMatch else { return }
        if isHome { match.homeSubs += 1 } else { match.awaySubs += 1 }
        currentMatch = match
    }

    // MARK: - Configuration Helpers
    public func configureMatch(
        duration: Int,
        periods: Int,
        halfTimeLength: Int,
        hasExtraTime: Bool,
        hasPenalties: Bool
    ) {
        newMatch = Match(
            duration: TimeInterval(duration * 60),
            numberOfPeriods: periods,
            halfTimeLength: TimeInterval(halfTimeLength * 60),
            extraTimeHalfLength: TimeInterval(extraTimeHalfLengthMinutes * 60),
            hasExtraTime: hasExtraTime,
            hasPenalties: hasPenalties,
            penaltyInitialRounds: penaltyInitialRounds
        )
        currentMatch = newMatch
        waitingForMatchStart = false
    }
    
    public func setKickingTeam(_ isHome: Bool) { homeTeamKickingOff = isHome }
    public func getSecondHalfKickingTeam() -> TeamSide { homeTeamKickingOff ? .away : .home }
    public func setKickingTeamET1(_ isHome: Bool) { homeTeamKickingOffET1 = isHome }
    public func getETSecondHalfKickingTeam() -> TeamSide {
        if let et1 = homeTeamKickingOffET1 { return et1 ? .away : .home }
        return getSecondHalfKickingTeam()
    }
    
    // MARK: - Match Event Recording
    public func recordEvent(_ eventType: MatchEventType, team: TeamSide? = nil, details: EventDetails) {
        let event = MatchEventRecord(
            matchTime: matchTime,
            period: currentPeriod,
            eventType: eventType,
            team: team,
            details: details
        )
        matchEvents.append(event)
    }
    
    public func recordGoal(
        team: TeamSide,
        goalType: GoalDetails.GoalType,
        playerNumber: Int? = nil,
        playerName: String? = nil
    ) {
        let goalDetails = GoalDetails(
            goalType: goalType,
            playerNumber: playerNumber,
            playerName: playerName
        )
        recordEvent(.goal(goalDetails), team: team, details: .goal(goalDetails))
        updateScore(isHome: team == .home, increment: true)
    }
    
    public func recordCard(
        team: TeamSide,
        cardType: CardDetails.CardType,
        recipientType: CardRecipientType,
        playerNumber: Int? = nil,
        playerName: String? = nil,
        officialRole: TeamOfficialRole? = nil,
        reason: String
    ) {
        let cardDetails = CardDetails(
            cardType: cardType,
            recipientType: recipientType,
            playerNumber: playerNumber,
            playerName: playerName,
            officialRole: officialRole,
            reason: reason
        )
        recordEvent(.card(cardDetails), team: team, details: .card(cardDetails))
        addCard(isHome: team == .home, isYellow: cardType == .yellow)
    }
    
    public func recordSubstitution(
        team: TeamSide,
        playerOut: Int? = nil,
        playerIn: Int? = nil,
        playerOutName: String? = nil,
        playerInName: String? = nil
    ) {
        let subDetails = SubstitutionDetails(
            playerOut: playerOut,
            playerIn: playerIn,
            playerOutName: playerOutName,
            playerInName: playerInName
        )
        recordEvent(.substitution(subDetails), team: team, details: .substitution(subDetails))
        addSubstitution(isHome: team == .home)
    }
    
    public func recordMatchEvent(_ eventType: MatchEventType) {
        recordEvent(eventType, team: nil, details: .general)
    }

    // MARK: - Penalties Flow
    public func beginPenaltiesIfNeeded() {
        guard !penaltyManager.isActive else { return }
        waitingForPenaltiesStart = false
        isMatchInProgress = false
        isPaused = false
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        if let match = currentMatch {
            currentPeriod = max(1, match.numberOfPeriods) + (match.hasExtraTime ? 2 : 0) + 1
        } else {
            currentPeriod = 5
        }
        if let match = currentMatch { penaltyManager.setInitialRounds(match.penaltyInitialRounds) }
        wirePenaltyCallbacks()
        penaltyManager.begin()
    }

    public func recordPenaltyAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int? = nil) {
        penaltyManager.recordAttempt(team: team, result: result, playerNumber: playerNumber)
    }

    public func endPenaltiesAndProceed() {
        if penaltyManager.isActive { penaltyManager.end() }
        waitingForPenaltiesStart = false
        isMatchInProgress = false
        isPaused = false
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        isFullTime = true
    }

    public func setPenaltyFirstKicker(_ team: TeamSide) {
        penaltyManager.setFirstKicker(team)
    }

    @discardableResult
    public func startPenalties(withFirstKicker team: TeamSide) -> Bool {
        beginPenaltiesIfNeeded()
        guard penaltyManager.isActive else { return false }
        penaltyManager.setFirstKicker(team)
        return true
    }
    
    // MARK: - Match Management Actions
    public func endCurrentPeriod() {
        recordMatchEvent(.periodEnd(currentPeriod))
        
        guard let match = currentMatch else { return }
        
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        
        if currentPeriod == 1 && match.numberOfPeriods >= 2 {
            isMatchInProgress = false
            isPaused = false
            waitingForHalfTimeStart = true
        } else if currentPeriod < match.numberOfPeriods {
            isMatchInProgress = false
            isPaused = false
            if currentPeriod == 1 { waitingForSecondHalfStart = true }
        } else if match.hasExtraTime && currentPeriod == match.numberOfPeriods {
            isMatchInProgress = false
            isPaused = false
            waitingForET1Start = true
        } else if match.hasExtraTime && currentPeriod == match.numberOfPeriods + 1 {
            isMatchInProgress = false
            isPaused = false
            waitingForET2Start = true
        } else if currentPeriod == match.numberOfPeriods + 2 {
            if match.hasPenalties { waitingForPenaltiesStart = true } else { endMatch() }
        } else {
            endMatch()
        }
    }
    
    public func resetMatch() {
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        currentPeriod = 1
        isMatchInProgress = false
        isPaused = false
        isHalfTime = false
        waitingForMatchStart = true
        waitingForHalfTimeStart = false
        waitingForSecondHalfStart = false
        waitingForET1Start = false
        waitingForET2Start = false
        waitingForPenaltiesStart = false
        isFullTime = false
        matchCompleted = false
        
        if let match = currentMatch {
            periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: 1)
        } else {
            periodTimeRemaining = "45:00"
        }
        halfTimeRemaining = "00:00"
        halfTimeElapsed = "00:00"
        formattedStoppageTime = "00:00"
        
        if let match = currentMatch {
            var resetMatch = match
            resetMatch.homeScore = 0
            resetMatch.awayScore = 0
            resetMatch.homeYellowCards = 0
            resetMatch.awayYellowCards = 0
            resetMatch.homeRedCards = 0
            resetMatch.awayRedCards = 0
            resetMatch.homeSubs = 0
            resetMatch.awaySubs = 0
            currentMatch = resetMatch
        }
        
        matchEvents.removeAll()
        homeTeamKickingOffET1 = nil
        penaltyManager.end()
    }
    
    @MainActor
    public func finalizeMatch() {
        recordMatchEvent(.matchEnd)
        if let match = currentMatch {
            let snapshot = CompletedMatch(
                match: match,
                events: matchEvents
            )
            do {
                try history.save(snapshot)
                connectivity?.sendCompletedMatch(snapshot)
            } catch {
                lastPersistenceError = error.localizedDescription
                haptics.play(.failure)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": "history save failed",
                        "context": "core.finalizeMatch.save"
                    ])
                }
            }
        }
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        isMatchInProgress = false
        isPaused = false
        isHalfTime = false
        waitingForHalfTimeStart = false
        waitingForSecondHalfStart = false
        isFullTime = true
        matchCompleted = true
        currentMatch = nil
    }
    
    public func abandonMatch() { recordMatchEvent(.matchEnd); endMatch() }
    public func navigateHome() { resetMatch(); currentMatch = nil }

    // MARK: - History Bridges
    @MainActor public func loadCompletedMatches() -> [CompletedMatch] { (try? history.loadAll()) ?? [] }
    @MainActor public func loadRecentCompletedMatches(limit: Int = 50) -> [CompletedMatch] { history.loadRecent(limit) }
    @MainActor public func latestCompletedMatchSummary() -> CompletedMatchSummary? {
        history.loadRecent(1).first.map { CompletedMatchSummary(match: $0) }
    }
    @MainActor public func deleteCompletedMatch(id: UUID) { try? history.delete(id: id) }

    // MARK: - Penalty Manager Wiring
    private func wirePenaltyCallbacks() {
        penaltyManager.onStart = { [weak self] in self?.recordMatchEvent(.penaltiesStart) }
        penaltyManager.onAttempt = { [weak self] team, details in
            self?.recordEvent(.penaltyAttempt(details), team: team, details: .penalty(details))
        }
        penaltyManager.onDecided = { _ in }
        penaltyManager.onEnd = { [weak self] in self?.recordMatchEvent(.penaltiesEnd) }
    }
    
    // MARK: - Manual Period Transitions
    public func startHalfTimeManually() {
        guard waitingForHalfTimeStart else { return }
        waitingForHalfTimeStart = false
        isHalfTime = true
        recordMatchEvent(.halfTime)
        if let match = currentMatch {
            timerManager.startHalfTime(match: match) { [weak self] elapsed in
                self?.halfTimeElapsed = elapsed
            }
        }
    }
    
    public func startSecondHalfManually() {
        guard waitingForSecondHalfStart else { return }
        waitingForSecondHalfStart = false
        isHalfTime = false
        currentPeriod = 2
        isMatchInProgress = true
        isPaused = false
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        recordMatchEvent(.periodStart(currentPeriod))
        if let match = currentMatch {
            self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
            timerManager.startPeriod(
                match: match,
                currentPeriod: currentPeriod,
                onTick: { [weak self] snap in
                    guard let self = self else { return }
                    self.matchTime = snap.matchTime
                    self.periodTime = snap.periodTime
                    self.periodTimeRemaining = snap.periodTimeRemaining
                    self.formattedStoppageTime = snap.formattedStoppageTime
                    self.isInStoppage = snap.isInStoppage
                },
                onPeriodEnd: { [weak self] in
                    self?.endPeriod()
                }
            )
        }
    }
    
    public func startExtraTimeFirstHalfManually() {
        guard waitingForET1Start, let match = currentMatch else { return }
        waitingForET1Start = false
        isHalfTime = false
        currentPeriod = max(1, match.numberOfPeriods) + 1 // ET1
        isMatchInProgress = true
        isPaused = false
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        recordMatchEvent(.periodStart(currentPeriod))
        self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
        timerManager.startPeriod(
            match: match,
            currentPeriod: currentPeriod,
            onTick: { [weak self] snap in
                guard let self = self else { return }
                self.matchTime = snap.matchTime
                self.periodTime = snap.periodTime
                self.periodTimeRemaining = snap.periodTimeRemaining
                self.formattedStoppageTime = snap.formattedStoppageTime
                self.isInStoppage = snap.isInStoppage
            },
            onPeriodEnd: { [weak self] in
                self?.endPeriod()
            }
        )
    }

    public func startExtraTimeSecondHalfManually() {
        guard waitingForET2Start, let match = currentMatch else { return }
        waitingForET2Start = false
        isHalfTime = false
        currentPeriod = max(1, match.numberOfPeriods) + 2 // ET2
        isMatchInProgress = true
        isPaused = false
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        recordMatchEvent(.periodStart(currentPeriod))
        self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
        timerManager.startPeriod(
            match: match,
            currentPeriod: currentPeriod,
            onTick: { [weak self] snap in
                guard let self = self else { return }
                self.matchTime = snap.matchTime
                self.periodTime = snap.periodTime
                self.periodTimeRemaining = snap.periodTimeRemaining
                self.formattedStoppageTime = snap.formattedStoppageTime
                self.isInStoppage = snap.isInStoppage
            },
            onPeriodEnd: { [weak self] in
                self?.endPeriod()
            }
        )
    }
    
    public func endHalfTimeManually() {
        timerManager.stopHalfTime()
        timer = nil
        isHalfTime = false
        halfTimeRemaining = "00:00"
        halfTimeElapsed = "00:00"
        waitingForSecondHalfStart = true
    }
    
    deinit {
        timerManager.stopAll()
        timer?.invalidate()
        stoppageTimer?.invalidate()
    }
}
