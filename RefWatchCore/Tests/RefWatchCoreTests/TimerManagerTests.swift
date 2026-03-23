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

    @MainActor
    func test_startHalfTime_whenThresholdReached_requestsCueOnce() async throws {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let tm = TimerManager(lifecycleHaptics: lifecycleHaptics)
        let match = Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1)

        tm.startHalfTime(match: match) { _ in }

        let reachedCue = self.waitUntil(timeoutSeconds: 3) {
            lifecycleHaptics.playedCues.count == 1
        }
        XCTAssertTrue(reachedCue)
        XCTAssertEqual(lifecycleHaptics.playedCues, [.halftimeDurationReached])
        XCTAssertTrue(tm.persistenceState().didRequestHalftimeDurationCue)
    }

    func test_restoreHalfTime_whenAlreadyPastThreshold_requestsCueImmediately() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let tm = TimerManager(lifecycleHaptics: lifecycleHaptics)
        let match = Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1)
        let state = TimerManager.PersistenceState(
            halfTimeStartTime: Date().addingTimeInterval(-2),
            didRequestHalftimeDurationCue: false)

        tm.restoreHalfTime(match: match, persistenceState: state) { _ in }

        XCTAssertEqual(lifecycleHaptics.playedCues, [.halftimeDurationReached])
        XCTAssertTrue(tm.persistenceState().didRequestHalftimeDurationCue)
    }

    func test_restoreHalfTime_whenCueAlreadyPersisted_doesNotReplayCue() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let tm = TimerManager(lifecycleHaptics: lifecycleHaptics)
        let match = Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1)
        let state = TimerManager.PersistenceState(
            halfTimeStartTime: Date().addingTimeInterval(-2),
            didRequestHalftimeDurationCue: true)

        tm.restoreHalfTime(match: match, persistenceState: state) { _ in }

        XCTAssertTrue(lifecycleHaptics.playedCues.isEmpty)
    }

    func test_stopHalfTime_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let tm = TimerManager(lifecycleHaptics: lifecycleHaptics)

        tm.stopHalfTime()

        XCTAssertEqual(lifecycleHaptics.cancelCount, 1)
    }

    func test_stopAll_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let tm = TimerManager(lifecycleHaptics: lifecycleHaptics)

        tm.stopAll()

        XCTAssertEqual(lifecycleHaptics.cancelCount, 1)
    }
}

private extension TimerManagerTests {
    @MainActor
    func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if condition() { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }

        return condition()
    }
}

private final class MatchLifecycleHapticsSpy: MatchLifecycleHapticsProviding {
    private(set) var playedCues: [MatchLifecycleHapticCue] = []
    private(set) var cancelCount: Int = 0

    func play(_ cue: MatchLifecycleHapticCue) {
        self.playedCues.append(cue)
    }

    func cancelPendingPlayback() {
        self.cancelCount += 1
    }
}
