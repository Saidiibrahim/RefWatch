//
//  MatchLifecycleCoordinator.swift
//  RefZoneWatchOS
//
//  Description: Central coordinator controlling the high-level match lifecycle
//  (start → setup → running → halftime → second-half kickoff → finished).
//

import Foundation
import Observation

@Observable
final class MatchLifecycleCoordinator {
    enum State: Equatable {
        case idle                 // Show StartMatchScreen
        case setup                // Show MatchSetupView (with Timer in middle)
        case kickoffFirstHalf     // Show MatchKickOffView (first half)
        case kickoffSecondHalf    // Show MatchKickOffView (second half)
        case kickoffExtraTimeFirstHalf // Show MatchKickOffView (ET first half)
        case kickoffExtraTimeSecondHalf // Show MatchKickOffView (ET second half)
        case countdown            // Show CountdownView before starting match/period
        case choosePenaltyFirstKicker // Show PenaltyFirstKickerView
        case penalties           // Show PenaltyShootoutView
        case finished             // Show FullTimeView
    }
    
    /// Enum representing the type of kickoff being performed
    enum KickoffType: Equatable {
        case firstHalf
        case secondHalf
        case et1
        case et2
    }

    private(set) var state: State = .idle
    var shouldPresentStartMatchScreen: Bool = false
    
    // Pending kickoff context stored during countdown transition
    var pendingKickoffType: KickoffType?
    var pendingKickingTeam: Bool? // true = home, false = away

    func resetToStart() {
        let old = state
        guard old != .idle else { return }
        state = .idle
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [resetToStart]")
        #endif
    }
    func goToSetup() {
        let old = state
        guard old != .setup else { return }
        state = .setup
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToSetup]")
        #endif
    }
    func goToKickoffFirst() {
        let old = state
        guard old != .kickoffFirstHalf else { return }
        state = .kickoffFirstHalf
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToKickoffFirst]")
        #endif
    }
    func goToKickoffSecond() {
        let old = state
        guard old != .kickoffSecondHalf else { return }
        state = .kickoffSecondHalf
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToKickoffSecond]")
        #endif
    }
    func goToKickoffETFirst() {
        let old = state
        guard old != .kickoffExtraTimeFirstHalf else { return }
        state = .kickoffExtraTimeFirstHalf
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToKickoffETFirst]")
        #endif
    }
    func goToKickoffETSecond() {
        let old = state
        guard old != .kickoffExtraTimeSecondHalf else { return }
        state = .kickoffExtraTimeSecondHalf
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToKickoffETSecond]")
        #endif
    }
    func goToChoosePenaltyFirstKicker() {
        let old = state
        guard old != .choosePenaltyFirstKicker else { return }
        state = .choosePenaltyFirstKicker
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToChoosePenaltyFirstKicker]")
        #endif
    }
    func goToPenalties() {
        let old = state
        guard old != .penalties else { return }
        state = .penalties
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToPenalties]")
        #endif
    }
    func goToFinished() {
        let old = state
        guard old != .finished else { return }
        state = .finished
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToFinished]")
        #endif
    }
    
    /// Transitions to countdown state with kickoff context
    /// - Parameters:
    ///   - kickoffType: The type of kickoff (firstHalf, secondHalf, et1, et2)
    ///   - team: true for home team, false for away team
    func goToCountdown(kickoffType: KickoffType, team: Bool) {
        let old = state
        guard old != .countdown else { return }
        pendingKickoffType = kickoffType
        pendingKickingTeam = team
        state = .countdown
        #if DEBUG
        print("DEBUG: Lifecycle transition: \(old) → \(state) [goToCountdown] type=\(kickoffType), team=\(team ? "home" : "away")")
        #endif
    }

    func requestStartMatchScreen() {
        let old = state
        if old != .idle {
            state = .idle
            #if DEBUG
            print("DEBUG: Lifecycle transition: \(old) → \(state) [requestStartMatchScreen]")
            #endif
        }
        shouldPresentStartMatchScreen = true
    }
}
