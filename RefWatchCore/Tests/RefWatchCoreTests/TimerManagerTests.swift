import XCTest
@testable import RefWatchCore

final class TimerManagerTests: XCTestCase {

    func test_configureInitialPeriodLabel_uses_per_period() async throws {
        let tm = TimerManager()
        let match = Match(
            duration: TimeInterval(50 * 60),
            numberOfPeriods: 2,
            halfTimeLength: TimeInterval(10 * 60)
        )

        let label = tm.configureInitialPeriodLabel(match: match, currentPeriod: 1)
        XCTAssertEqual(label, "25:00")
    }

    func test_configureInitialPeriodLabel_handles_zero_periods() async throws {
        let tm = TimerManager()
        let match = Match(
            duration: TimeInterval(40 * 60),
            numberOfPeriods: 0, // invalid; manager should guard to 1
            halfTimeLength: TimeInterval(10 * 60)
        )

        let label = tm.configureInitialPeriodLabel(match: match, currentPeriod: 1)
        XCTAssertEqual(label, "40:00")
    }

    func test_pause_resume_no_crash_without_start() async throws {
        let tm = TimerManager()
        tm.pause { _ in }
        tm.resume { _ in }
        tm.stopAll()
        // success is not crashing
    }

    func test_stopAll_is_idempotent() async throws {
        let tm = TimerManager()
        tm.stopAll()
        tm.stopAll()
        // success is not crashing
    }
}

