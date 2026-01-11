import XCTest
@testable import RefWatchCore

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

  func setInitialRounds(_ rounds: Int) {}
  func begin() { /* never activates */ }
  func setFirstKicker(_ team: TeamSide) { self.firstKicker = team; self.hasChosenFirstKicker = true }
  func markHasChosenFirstKicker(_ chosen: Bool) { self.hasChosenFirstKicker = chosen }
  func recordAttempt(team: TeamSide, result: PenaltyAttemptDetails.Result, playerNumber: Int?) {}
  func undoLastAttempt() -> PenaltyUndoResult? { nil }
  func swapKickingOrder() {}
  func end() { self.isActive = false }

  var onStart: (() -> Void)?
  var onAttempt: ((TeamSide, PenaltyAttemptDetails) -> Void)?
  var onDecided: ((TeamSide) -> Void)?
  var onEnd: (() -> Void)?
}

@MainActor
final class PenaltiesStartFailureTests: XCTestCase {
  func test_startPenalties_whenManagerBeginFails_returnsFalse() async throws {
    let failing = FakePenaltyManagerNeverBegins()
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let vm = MatchViewModel(
      history: MatchHistoryService(baseDirectory: tmp),
      penaltyManager: failing)

    vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
    let ok = vm.startPenalties(withFirstKicker: .away)

    XCTAssertFalse(ok)
    XCTAssertFalse(vm.penaltyShootoutActive)
    XCTAssertFalse(vm.hasChosenPenaltyFirstKicker)
  }
}
