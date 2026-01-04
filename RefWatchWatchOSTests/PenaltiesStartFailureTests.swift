//
//  PenaltiesStartFailureTests.swift
//  RefWatch Watch AppTests
//

import RefWatchCore
import Testing
@testable import RefWatch_Watch_App

// A simple fake that never activates on begin(), allowing us to simulate
// a failure path for startPenalties(withFirstKicker:).
final class FakePenaltyManagerNeverBegins: PenaltyManaging {
  var isActive: Bool = false
  var isDecided: Bool = false
  var winner: TeamSide?

  var firstKicker: TeamSide = .home
  var hasChosenFirstKicker: Bool = false

  var homeTaken: Int = 0
  var homeScored: Int = 0
  var homeResults: [PenaltyAttemptDetails.Result] = []
  var awayTaken: Int = 0
  var awayScored: Int = 0
  var awayResults: [PenaltyAttemptDetails.Result] = []

  var roundsVisible: Int { 5 }
  var nextTeam: TeamSide { .home }
  var isSuddenDeathActive: Bool { false }

  func setInitialRounds(_ rounds: Int) { /* no-op */ }
  func begin() { /* never activates */ }
  func setFirstKicker(_ team: TeamSide) { self.firstKicker = team; self.hasChosenFirstKicker = true }
  func markHasChosenFirstKicker(_ chosen: Bool) { self.hasChosenFirstKicker = chosen }
  func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int?) { /* no-op */ }
  func undoLastAttempt() -> PenaltyUndoResult? { nil }
  func swapKickingOrder() {}
  func end() { self.isActive = false }

  var onStart: (() -> Void)?
  var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)?
  var onDecided: ((TeamSide) -> Void)?
  var onEnd: (() -> Void)?
}

@MainActor
struct PenaltiesStartFailureTests {
  @Test
  func test_startPenalties_whenManagerBeginFails_returnsFalse() async throws {
    let failing = FakePenaltyManagerNeverBegins()
    let vm = MatchViewModel(history: InMemoryHistoryStore(), penaltyManager: failing)

    // Configure a match to ensure period math is valid
    vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)

    // Attempt to start penalties with a first kicker
    let ok = vm.startPenalties(withFirstKicker: .away)

    // Should fail because manager never becomes active
    #expect(ok == false)
    #expect(vm.penaltyShootoutActive == false)
    #expect(vm.hasChosenPenaltyFirstKicker == false)
  }
}
