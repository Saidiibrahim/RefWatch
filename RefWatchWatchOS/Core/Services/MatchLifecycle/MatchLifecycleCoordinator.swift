//
//  MatchLifecycleCoordinator.swift
//  RefWatchWatchOS
//
//  Description: Central coordinator controlling the high-level match lifecycle
//  (start → setup → running → halftime → second-half kickoff → finished).
//

import Foundation
import Observation

@Observable
final class MatchLifecycleCoordinator {
  enum State: Equatable {
    case idle // Show StartMatchScreen
    case setup // Show MatchSetupView (with Timer in middle)
    case kickoffFirstHalf // Show MatchKickOffView (first half)
    case kickoffSecondHalf // Show MatchKickOffView (second half)
    case kickoffExtraTimeFirstHalf // Show MatchKickOffView (ET first half)
    case kickoffExtraTimeSecondHalf // Show MatchKickOffView (ET second half)
    case countdown // Show CountdownView before starting match/period
    case choosePenaltyFirstKicker // Show PenaltyFirstKickerView
    case penalties // Show PenaltyShootoutView
    case finished // Show FullTimeView
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
    let old = self.state
    guard old != .idle else { return }
    self.state = .idle
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [resetToStart]")
    #endif
  }

  func goToSetup() {
    let old = self.state
    guard old != .setup else { return }
    self.state = .setup
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToSetup]")
    #endif
  }

  func goToKickoffFirst() {
    let old = self.state
    guard old != .kickoffFirstHalf else { return }
    self.state = .kickoffFirstHalf
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToKickoffFirst]")
    #endif
  }

  func goToKickoffSecond() {
    let old = self.state
    guard old != .kickoffSecondHalf else { return }
    self.state = .kickoffSecondHalf
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToKickoffSecond]")
    #endif
  }

  func goToKickoffETFirst() {
    let old = self.state
    guard old != .kickoffExtraTimeFirstHalf else { return }
    self.state = .kickoffExtraTimeFirstHalf
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToKickoffETFirst]")
    #endif
  }

  func goToKickoffETSecond() {
    let old = self.state
    guard old != .kickoffExtraTimeSecondHalf else { return }
    self.state = .kickoffExtraTimeSecondHalf
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToKickoffETSecond]")
    #endif
  }

  func goToChoosePenaltyFirstKicker() {
    let old = self.state
    guard old != .choosePenaltyFirstKicker else { return }
    self.state = .choosePenaltyFirstKicker
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToChoosePenaltyFirstKicker]")
    #endif
  }

  func goToPenalties() {
    let old = self.state
    guard old != .penalties else { return }
    self.state = .penalties
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToPenalties]")
    #endif
  }

  func goToFinished() {
    let old = self.state
    guard old != .finished else { return }
    self.state = .finished
    #if DEBUG
    print("DEBUG: Lifecycle transition: \(old) → \(self.state) [goToFinished]")
    #endif
  }

  /// Transitions to countdown state with kickoff context
  /// - Parameters:
  ///   - kickoffType: The type of kickoff (firstHalf, secondHalf, et1, et2)
  ///   - team: true for home team, false for away team
  func goToCountdown(kickoffType: KickoffType, team: Bool) {
    let old = self.state
    guard old != .countdown else { return }
    self.pendingKickoffType = kickoffType
    self.pendingKickingTeam = team
    self.state = .countdown
    #if DEBUG
    print(
      "DEBUG: Lifecycle transition: \(old) → \(self.state) [goToCountdown] " +
        "type=\(kickoffType), team=\(team ? "home" : "away")")
    #endif
  }

  func requestStartMatchScreen() {
    let old = self.state
    if old != .idle {
      self.state = .idle
      #if DEBUG
      print("DEBUG: Lifecycle transition: \(old) → \(self.state) [requestStartMatchScreen]")
      #endif
    }
    self.shouldPresentStartMatchScreen = true
  }
}
