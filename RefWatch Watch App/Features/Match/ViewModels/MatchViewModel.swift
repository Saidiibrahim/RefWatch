//
//  MatchViewModel.swift
//  RefereeAssistant
//
//  Description: ViewModel controlling match timing, periods, and statistics.
//

import Foundation
import SwiftUI
import Observation
// Timer responsibilities delegated to TimerManager (SRP)

// MARK: - TimerManager Integration

@Observable
final class MatchViewModel {
    // MARK: - Properties
    private(set) var currentMatch: Match?
    private(set) var savedMatches: [Match]
    
    var newMatch: Match
    var isMatchInProgress: Bool = false
    var currentPeriod: Int = 1
    var isHalfTime: Bool = false
    var isPaused: Bool = false
    
    // Period transition states
    var waitingForMatchStart: Bool = true
    var waitingForHalfTimeStart: Bool = false
    var waitingForSecondHalfStart: Bool = false
    var isFullTime: Bool = false
    var matchCompleted: Bool = false
    
    // Timer properties (delegated)
    private let timerManager = TimerManager()
    // Legacy fields retained for API compatibility/unused paths
    private var timer: Timer? // no longer used
    private var stoppageTimer: Timer? // no longer used
    private var elapsedTime: TimeInterval = 0 // maintained for formattedElapsedTime
    // Removed legacy start time fields (managed internally by TimerManager)
    
    // Formatted time strings
    var matchTime: String = "00:00"
    var periodTime: String = "00:00"
    var periodTimeRemaining: String = "00:00"
    var halfTimeRemaining: String = "00:00"
    var halfTimeElapsed: String = "00:00"
    
    // Stoppage time tracking
    private var stoppageTime: TimeInterval = 0 // managed by TimerManager; retained for reset compatibility
    private var stoppageStartTime: Date? // no longer used
    var isInStoppage: Bool = false
    var formattedStoppageTime: String = "00:00"
    
    var formattedElapsedTime: String {
        if isMatchInProgress {
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
        return "00:00"
    }
    
    var homeTeam: String = "HOM"
    var awayTeam: String = "AWA"
    
    // Legacy per-team event storage removed in favor of unified matchEvents
    
    // Comprehensive match event tracking
    private(set) var matchEvents: [MatchEventRecord] = []
    
    // Add these properties
    var matchDuration: Int = 90
    var numberOfPeriods: Int = 2
    var halfTimeLength: Int = 15
    var hasExtraTime: Bool = false
    var hasPenalties: Bool = false
    
    // Add near the top with other properties
    private(set) var homeTeamKickingOff: Bool = false
    
    // MARK: - Initialization
    init() {
        self.savedMatches = [
            Match(homeTeam: "Leeds United", awayTeam: "Newcastle United")
        ]
        self.newMatch = Match()
    }
    
    // MARK: - Match Management
    func createMatch() {
        currentMatch = newMatch
        savedMatches.append(newMatch)
        newMatch = Match()
    }
    
    func selectMatch(_ match: Match) {
        currentMatch = match
    }
    
    // MARK: - Timer Control
    func startMatch() {
        #if DEBUG
        print("DEBUG: startMatch called")
        #endif
        guard let match = currentMatch else {
            #if DEBUG
            print("DEBUG: No current match found")
            #endif
            return
        }
        
        // Only start if not already in progress to prevent restarts
        if !isMatchInProgress {
            #if DEBUG
            print("DEBUG: Starting new match")
            #endif
            isMatchInProgress = true
            isPaused = false
            waitingForMatchStart = false
            // Mark match as started
            if var m = currentMatch {
                m.startTime = Date()
                currentMatch = m
            }
            // Initialize remaining time display from configured period
            if let match = currentMatch {
                self.periodTimeRemaining = timerManager.configureInitialPeriodLabel(match: match, currentPeriod: currentPeriod)
            }
            
            // Clean up any running timers
            stoppageTimer?.invalidate()
            stoppageTimer = nil
            
            // Reset stoppage time for new match
            timerManager.resetForNewPeriod()
            stoppageTime = 0
            stoppageStartTime = nil
            isInStoppage = false
            formattedStoppageTime = "00:00"
            
            // Record kick-off event
            recordMatchEvent(.kickOff)
            recordMatchEvent(.periodStart(currentPeriod))
            
            #if DEBUG
            print("DEBUG: Starting timer via TimerManager")
            #endif
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
        } else {
            #if DEBUG
            print("DEBUG: Match already in progress, not restarting")
            #endif
        }
    }
    
    func pauseMatch() {
        isPaused = true
        timerManager.pause { [weak self] snap in
            guard let self = self else { return }
            self.formattedStoppageTime = snap.formattedStoppageTime
            self.isInStoppage = snap.isInStoppage
        }
    }
    
    func resumeMatch() {
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
    
    func startNextPeriod() {
        currentPeriod += 1
        isHalfTime = false
        
        // Reset stoppage time for new period
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        
        // Record period start event
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
    
    func startHalfTime() {
        guard let match = currentMatch else { return }
        isHalfTime = true
        timerManager.startHalfTime(match: match) { [weak self] elapsed in
            self?.halfTimeElapsed = elapsed
        }
    }
    
    private func startTimer() { /* Timer handled by TimerManager */ }
    
    private func startHalfTimeTimer() { /* Half-time handled by TimerManager */ }
    
    private func updateStoppageTime() { /* Managed by TimerManager */ }
    
    private func updateMatchTime() { /* Managed by TimerManager */ }
    
    private func updateHalfTimeRemaining() { /* Managed by TimerManager */ }
    
    private func endPeriod() {
        pauseMatch()
        
        guard let match = currentMatch else { return }
        
        if currentPeriod < match.numberOfPeriods {
            if currentPeriod == match.numberOfPeriods / 2 {
                startHalfTime()
            }
        } else if match.hasExtraTime && currentPeriod == match.numberOfPeriods {
            // Handle extra time if needed
            currentPeriod += 1
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
    func updateScore(isHome: Bool, increment: Bool = true) {
        guard var match = currentMatch else { 
            #if DEBUG
            print("DEBUG: updateScore called but no current match found")
            #endif
            return 
        }
        
        let oldHomeScore = match.homeScore
        let oldAwayScore = match.awayScore
        
        #if DEBUG
        print("DEBUG: updateScore called - isHome: \(isHome), increment: \(increment)")
        print("DEBUG: Score before update - Home: \(oldHomeScore), Away: \(oldAwayScore)")
        #endif
        
        if isHome {
            match.homeScore += increment ? 1 : -1
        } else {
            match.awayScore += increment ? 1 : -1
        }
        
        currentMatch = match
        
        #if DEBUG
        print("DEBUG: Score after update - Home: \(match.homeScore), Away: \(match.awayScore)")
        print("DEBUG: Score successfully updated")
        #endif
    }
    
    func addCard(isHome: Bool, isYellow: Bool) {
        guard var match = currentMatch else { return }
        if isHome {
            if isYellow {
                match.homeYellowCards += 1
            } else {
                match.homeRedCards += 1
            }
        } else {
            if isYellow {
                match.awayYellowCards += 1
            } else {
                match.awayRedCards += 1
            }
        }
        currentMatch = match
    }
    
    func addSubstitution(isHome: Bool) {
        guard var match = currentMatch else { return }
        if isHome {
            match.homeSubs += 1
        } else {
            match.awaySubs += 1
        }
        currentMatch = match
    }

    
    // Add this method
    func configureMatch(
        duration: Int,
        periods: Int,
        halfTimeLength: Int,
        hasExtraTime: Bool,
        hasPenalties: Bool
    ) {
        #if DEBUG
        print("DEBUG: Configuring match")
        #endif
        newMatch = Match(
            duration: TimeInterval(duration * 60), // Convert minutes to seconds
            numberOfPeriods: periods,
            halfTimeLength: TimeInterval(halfTimeLength * 60), // Convert minutes to seconds
            hasExtraTime: hasExtraTime,
            hasPenalties: hasPenalties
        )
        currentMatch = newMatch
        
        // Auto-start the match after configuration to skip confirmation step
        waitingForMatchStart = false
        #if DEBUG
        print("DEBUG: Match configured and auto-started, currentMatch: \(String(describing: currentMatch))")
        #endif
    }
    
    // Add this new method
    func setKickingTeam(_ isHome: Bool) {
        homeTeamKickingOff = isHome
    }
    
    /// Get the team that should kick off the second half (already switched in endCurrentPeriod)
    func getSecondHalfKickingTeam() -> MatchKickOffView.Team {
        // Return the opposite team from the first half (standard football rules)
        return homeTeamKickingOff ? .away : .home
    }
    
    // MARK: - Match Event Recording
    
    /// Record a detailed match event with full context
    func recordEvent(_ eventType: MatchEventType, team: TeamSide? = nil, details: EventDetails) {
        let event = MatchEventRecord(
            matchTime: matchTime,
            period: currentPeriod,
            eventType: eventType,
            team: team,
            details: details
        )
        matchEvents.append(event)
        #if DEBUG
        if let team = team {
            print("DEBUG: Recorded event - \(event.eventType.displayName) for \(team.rawValue) at \(matchTime)")
        } else {
            print("DEBUG: Recorded event - \(event.eventType.displayName) (general) at \(matchTime)")
        }
        #endif
    }
    
    /// Record a goal event
    func recordGoal(
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
        
        // Update score
        updateScore(isHome: team == .home, increment: true)
    }
    
    /// Record a card event
    func recordCard(
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
        
        // Update card statistics
        addCard(isHome: team == .home, isYellow: cardType == .yellow)
    }
    
    /// Record a substitution event
    func recordSubstitution(
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
        
        // Update substitution statistics
        addSubstitution(isHome: team == .home)
    }
    
    /// Record match flow events (kick off, period changes, etc.)
    func recordMatchEvent(_ eventType: MatchEventType) {
        // For match events that don't have a specific team
        recordEvent(eventType, team: nil, details: .general)
    }
    
    // MARK: - Match Management Actions
    
    /// End the current half/period
    func endCurrentPeriod() {
        recordMatchEvent(.periodEnd(currentPeriod))
        
        guard let match = currentMatch else { return }
        
        // Stop the match timer
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        
        // Set appropriate waiting state
        if currentPeriod == 1 && match.numberOfPeriods >= 2 {
            // End of first half - wait for half time to start
            isMatchInProgress = false
            isPaused = false
            waitingForHalfTimeStart = true
        } else if currentPeriod < match.numberOfPeriods {
            // More regular periods to go - wait for next period
            isMatchInProgress = false
            isPaused = false
            if currentPeriod == 1 {
                waitingForSecondHalfStart = true
                // Keep original kick-off team - getSecondHalfKickingTeam will return opposite
            }
        } else if match.hasExtraTime && currentPeriod == match.numberOfPeriods {
            // TODO: Handle extra time waiting state
            currentPeriod += 1
            startNextPeriod()
        } else {
            // Match is over
            endMatch()
        }
    }
    
    /// Reset the match to initial state
    func resetMatch() {
        // Stop all timers
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        
        // Reset match state
        isMatchInProgress = false
        currentPeriod = 1
        isHalfTime = false
        isPaused = false
        
        // Reset transition states
        waitingForMatchStart = true
        waitingForHalfTimeStart = false
        waitingForSecondHalfStart = false
        isFullTime = false
        matchCompleted = false
        
        // Reset timing
        elapsedTime = 0
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        
        // Reset display values
        matchTime = "00:00"
        periodTime = "00:00"
        // Compute per-period remaining from current match or fall back to 45:00
        if let m = currentMatch {
            let periods = max(1, m.numberOfPeriods)
            let per = (m.duration / TimeInterval(periods))
            let perClamped = max(0, per)
            let mm = Int(perClamped) / 60
            let ss = Int(perClamped) % 60
            periodTimeRemaining = String(format: "%02d:%02d", mm, ss)
        } else {
            periodTimeRemaining = "45:00"
        }
        halfTimeRemaining = "00:00"
        halfTimeElapsed = "00:00"
        formattedStoppageTime = "00:00"
        
        // Reset match data
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
        
        // Clear events
        matchEvents.removeAll()
        
        #if DEBUG
        print("DEBUG: Match reset successfully")
        #endif
    }
    
    /// Finalize the match and prepare for navigation back to home
    func finalizeMatch() {
        recordMatchEvent(.matchEnd)
        
        // Stop all timers first
        timerManager.stopAll()
        timer = nil
        stoppageTimer = nil
        
        // Ensure stable terminal state so UI doesn't show intermediate screens
        isMatchInProgress = false
        isPaused = false
        isHalfTime = false
        waitingForHalfTimeStart = false
        waitingForSecondHalfStart = false
        isFullTime = true // Keep full-time active until navigation completes
        
        // Clear match and mark completed
        matchCompleted = true
        currentMatch = nil
        
        #if DEBUG
        print("DEBUG: Match finalized successfully")
        #endif
    }
    
    /// Abandon the match
    func abandonMatch() {
        recordMatchEvent(.matchEnd)
        endMatch()
        #if DEBUG
        print("DEBUG: Match abandoned")
        #endif
    }
    
    /// Navigate home (reset to no current match)
    func navigateHome() {
        resetMatch()
        currentMatch = nil
        #if DEBUG
        print("DEBUG: Navigated home")
        #endif
    }
    
    // MARK: - Manual Period Transitions
    
    /// Start half-time manually
    func startHalfTimeManually() {
        guard waitingForHalfTimeStart else { return }
        
        waitingForHalfTimeStart = false
        isHalfTime = true
        
        recordMatchEvent(.halfTime)
        if let match = currentMatch {
            timerManager.startHalfTime(match: match) { [weak self] elapsed in
                self?.halfTimeElapsed = elapsed
            }
        }
        
        #if DEBUG
        print("DEBUG: Half-time started manually")
        #endif
    }
    
    /// Start second half manually
    func startSecondHalfManually() {
        guard waitingForSecondHalfStart else { return }
        
        waitingForSecondHalfStart = false
        isHalfTime = false
        currentPeriod = 2
        isMatchInProgress = true
        isPaused = false
        
        // Reset stoppage time for new period
        timerManager.resetForNewPeriod()
        stoppageTime = 0
        stoppageStartTime = nil
        isInStoppage = false
        formattedStoppageTime = "00:00"
        
        // Record period start
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
        
        #if DEBUG
        print("DEBUG: Second half started manually")
        #endif
    }
    
    /// End half-time and prepare for second half
    func endHalfTimeManually() {
        timerManager.stopHalfTime()
        timer = nil
        isHalfTime = false
        halfTimeRemaining = "00:00"
        halfTimeElapsed = "00:00"
        
        // Switch to waiting for second half
        waitingForSecondHalfStart = true
        
        #if DEBUG
        print("DEBUG: Half-time ended, waiting for second half start")
        #endif
    }
    
    deinit {
        // Ensure timers are invalidated to avoid retain cycles or leaks
        timerManager.stopAll()
        timer?.invalidate()
        stoppageTimer?.invalidate()
    }
}
