import XCTest
@testable import RefWatchCore

@MainActor
final class MatchViewModel_TimeConversionTests: XCTestCase {

    func test_configureMatch_converts_minutes_to_seconds() async throws {
        let vm = MatchViewModel()

        vm.configureMatch(
            duration: 50,
            periods: 2,
            halfTimeLength: 15,
            hasExtraTime: false,
            hasPenalties: false
        )

        guard let match = vm.currentMatch else { return XCTFail("Expected currentMatch") }
        XCTAssertEqual(match.duration, TimeInterval(50 * 60))
        XCTAssertEqual(match.halfTimeLength, TimeInterval(15 * 60))
        XCTAssertEqual(match.numberOfPeriods, 2)
    }

    func test_resetMatch_uses_per_period_for_remaining_label() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(
            duration: 50,
            periods: 2,
            halfTimeLength: 10,
            hasExtraTime: false,
            hasPenalties: false
        )

        vm.resetMatch()
        XCTAssertEqual(vm.periodTimeRemaining, "25:00")
    }

    func test_safe_denominator_when_periods_is_zero() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(
            duration: 40,
            periods: 0,
            halfTimeLength: 10,
            hasExtraTime: false,
            hasPenalties: false
        )
        vm.startMatch()
        XCTAssertEqual(vm.periodTimeRemaining, "40:00")
    }
}
