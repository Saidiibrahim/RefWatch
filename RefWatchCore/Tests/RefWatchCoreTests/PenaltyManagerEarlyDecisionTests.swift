import XCTest
@testable import RefWatchCore

final class PenaltyManagerEarlyDecisionTests: XCTestCase {
  func test_decidesEarly_whenTrailingCannotCatchWithEqualRemainingKicks() {
    let manager = PenaltyManager(initialRounds: 5)
    manager.begin()

    // After three rounds: home 3/3, away 0/3. Away has only two kicks left
    // and cannot reach three goals, so the shootout should be decided now.
    (0..<3).forEach { _ in
      manager.recordAttempt(team: .home, result: .scored)
      manager.recordAttempt(team: .away, result: .missed)
    }

    XCTAssertTrue(manager.isDecided)
    XCTAssertEqual(manager.winner, .home)
  }

  func test_doesNotDecide_whenTrailingStillHasMathematicalChance() {
    let manager = PenaltyManager(initialRounds: 5)
    manager.begin()

    // Home leads 1-0 after first round; away still has full remaining kicks
    manager.recordAttempt(team: .home, result: .scored)
    manager.recordAttempt(team: .away, result: .missed)

    XCTAssertFalse(manager.isDecided)
    XCTAssertNil(manager.winner)
  }
}
