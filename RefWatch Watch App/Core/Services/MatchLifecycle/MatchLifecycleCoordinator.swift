//
//  MatchLifecycleCoordinator.swift
//  RefWatch Watch App
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
        case choosePenaltyFirstKicker // Show PenaltyFirstKickerView
        case penalties           // Show PenaltyShootoutView
        case finished             // Show FullTimeView
    }

    private(set) var state: State = .idle

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
}
