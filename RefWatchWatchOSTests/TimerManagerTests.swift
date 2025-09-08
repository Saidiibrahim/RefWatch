//
//  TimerManagerTests.swift
//  RefWatch Watch AppTests
//

import Foundation
import Testing
@testable import RefWatch_Watch_App

struct TimerManagerTests {

    @Test
    func test_configureInitialPeriodLabel_uses_per_period() async throws {
        let tm = TimerManager()
        let match = Match(
            duration: TimeInterval(50 * 60),
            numberOfPeriods: 2,
            halfTimeLength: TimeInterval(10 * 60)
        )

        let label = tm.configureInitialPeriodLabel(match: match, currentPeriod: 1)
        #expect(label == "25:00")
    }

    @Test
    func test_configureInitialPeriodLabel_handles_zero_periods() async throws {
        let tm = TimerManager()
        let match = Match(
            duration: TimeInterval(40 * 60),
            numberOfPeriods: 0, // invalid; manager should guard to 1
            halfTimeLength: TimeInterval(10 * 60)
        )

        let label = tm.configureInitialPeriodLabel(match: match, currentPeriod: 1)
        // With 0 periods guarded to 1, full duration counts as a single period
        #expect(label == "40:00")
    }

    @Test
    func test_pause_resume_no_crash_without_start() async throws {
        let tm = TimerManager()
        // Pause and resume without calling startPeriod should not crash
        tm.pause { _ in }
        tm.resume { _ in }
        tm.stopAll()
        // No expectations; success is not crashing
    }

    @Test
    func test_stopAll_is_idempotent() async throws {
        let tm = TimerManager()
        tm.stopAll()
        tm.stopAll()
        // No expectations; success is not crashing
    }
}

