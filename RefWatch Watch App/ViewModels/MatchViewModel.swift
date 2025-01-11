//
//  MatchViewModel.swift
//  RefereeAssistant
//
//  Description: ViewModel controlling match timing, periods, and statistics.
//

import Foundation
import SwiftUI
import Observation

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
    
    // Timer properties
    private var timer: Timer?
    private var elapsedTime: TimeInterval = 0
    private var periodStartTime: Date?
    private var halfTimeStartTime: Date?
    
    // Formatted time strings
    var matchTime: String = "00:00"
    var periodTime: String = "00:00"
    var halfTimeRemaining: String = "00:00"
    
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
    
    // Match events storage
    private var homeEvents: [MatchEvent] = []
    private var awayEvents: [MatchEvent] = []
    
    // Add these properties
    var matchDuration: Int = 90
    var numberOfPeriods: Int = 2
    var halfTimeLength: Int = 15
    var hasExtraTime: Bool = false
    var hasPenalties: Bool = false
    
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
        guard let match = currentMatch else { return }
        isMatchInProgress = true
        isPaused = false
        periodStartTime = Date()
        startTimer()
    }
    
    func pauseMatch() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    func resumeMatch() {
        isPaused = false
        startTimer()
    }
    
    func startNextPeriod() {
        currentPeriod += 1
        isHalfTime = false
        periodStartTime = Date()
        startTimer()
    }
    
    func startHalfTime() {
        guard let match = currentMatch else { return }
        isHalfTime = true
        halfTimeStartTime = Date()
        startHalfTimeTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMatchTime()
        }
    }
    
    private func startHalfTimeTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateHalfTimeRemaining()
        }
    }
    
    private func updateMatchTime() {
        guard let match = currentMatch,
              let startTime = periodStartTime else { return }
        
        let currentTime = Date()
        let periodElapsed = currentTime.timeIntervalSince(startTime)
        
        // Update period time
        let periodMinutes = Int(periodElapsed) / 60
        let periodSeconds = Int(periodElapsed) % 60
        periodTime = String(format: "%02d:%02d", periodMinutes, periodSeconds)
        
        // Update total match time
        elapsedTime = (TimeInterval(currentPeriod - 1) * (match.duration / TimeInterval(match.numberOfPeriods))) + periodElapsed
        let totalMinutes = Int(elapsedTime) / 60
        let totalSeconds = Int(elapsedTime) % 60
        matchTime = String(format: "%02d:%02d", totalMinutes, totalSeconds)
        
        // Check if period should end
        let periodDuration = match.duration / TimeInterval(match.numberOfPeriods)
        if periodElapsed >= periodDuration {
            endPeriod()
        }
    }
    
    private func updateHalfTimeRemaining() {
        guard let match = currentMatch,
              let startTime = halfTimeStartTime else { return }
        
        let currentTime = Date()
        let elapsed = currentTime.timeIntervalSince(startTime)
        let remaining = match.halfTimeLength * 60 - elapsed
        
        if remaining <= 0 {
            endHalfTime()
            return
        }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        halfTimeRemaining = String(format: "%02d:%02d", minutes, seconds)
    }
    
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
        timer?.invalidate()
        timer = nil
        isHalfTime = false
        halfTimeRemaining = "00:00"
    }
    
    private func endMatch() {
        isMatchInProgress = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Match Statistics
    func updateScore(isHome: Bool, increment: Bool = true) {
        guard var match = currentMatch else { return }
        if isHome {
            match.homeScore += increment ? 1 : -1
        } else {
            match.awayScore += increment ? 1 : -1
        }
        currentMatch = match
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
    
    func addEvent(_ event: MatchEvent, for team: Team) {
        switch team {
        case .home:
            homeEvents.append(event)
        case .away:
            awayEvents.append(event)
        }
    }
    
    enum Team {
        case home, away
    }
    
    // Add this method
    func configureMatch(
        duration: Int,
        periods: Int,
        halfTimeLength: Int,
        hasExtraTime: Bool,
        hasPenalties: Bool
    ) {
        newMatch = Match(
            duration: TimeInterval(duration),
            numberOfPeriods: periods,
            halfTimeLength: TimeInterval(halfTimeLength),
            hasExtraTime: hasExtraTime,
            hasPenalties: hasPenalties
        )
        currentMatch = newMatch
    }
}
