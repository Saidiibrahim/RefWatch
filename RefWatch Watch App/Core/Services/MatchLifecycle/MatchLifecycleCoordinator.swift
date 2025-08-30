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
        case finished             // Show FullTimeView
    }

    private(set) var state: State = .idle

    func resetToStart() { state = .idle }
    func goToSetup() { state = .setup }
    func goToKickoffFirst() { state = .kickoffFirstHalf }
    func goToKickoffSecond() { state = .kickoffSecondHalf }
    func goToFinished() { state = .finished }
}

