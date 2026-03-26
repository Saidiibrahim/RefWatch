import XCTest
@testable import RefWatchCore

@MainActor
final class MatchViewModel_EventsAndStoppageTests: XCTestCase {

    func test_event_order_after_start_and_goal() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        XCTAssertGreaterThanOrEqual(vm.matchEvents.count, 2)
        if vm.matchEvents.count >= 2 {
            switch vm.matchEvents[0].eventType {
            case .kickOff: break
            default: XCTFail("First event should be kickOff")
            }
            switch vm.matchEvents[1].eventType {
            case .periodStart(let p):
                XCTAssertEqual(p, 1)
            default:
                XCTFail("Second event should be periodStart(1)")
            }
        }

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        guard let last = vm.matchEvents.last else { return XCTFail("Expected last event") }
        switch last.eventType {
        case .goal(let details):
            XCTAssertEqual(details.goalType, .regular)
            XCTAssertEqual(last.team, .home)
        default:
            XCTFail("Last event should be a regular goal for home")
        }
    }

    func test_regular_and_own_goal_scoring_updates_correct_side() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.startMatch()

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        XCTAssertEqual(vm.currentMatch?.homeScore, 1)
        XCTAssertEqual(vm.currentMatch?.awayScore, 0)

        vm.recordGoal(team: .away, goalType: .ownGoal, playerNumber: 5)
        XCTAssertEqual(vm.currentMatch?.homeScore, 1)
        XCTAssertEqual(vm.currentMatch?.awayScore, 1)
    }

    func test_stoppage_accumulates_across_pauses() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_200_000_000)
        vm.resumeMatch()
        let first = parseMMSS(vm.formattedStoppageTime)
        XCTAssertGreaterThanOrEqual(first, 1)

        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_100_000_000)
        vm.resumeMatch()
        let second = parseMMSS(vm.formattedStoppageTime)
        XCTAssertGreaterThanOrEqual(second, 2)
    }

    func test_goal_sets_pending_confirmation() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        XCTAssertNil(vm.pendingConfirmation)

        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)

        guard let confirmation = vm.pendingConfirmation else {
            return XCTFail("Expected pending confirmation after recording goal")
        }

        switch confirmation.event.eventType {
        case .goal(let details):
            XCTAssertEqual(details.goalType, .regular)
        default:
            XCTFail("Expected goal event in pending confirmation")
        }
        XCTAssertEqual(confirmation.event.team, .home)

        await vm.clearPendingConfirmation(id: confirmation.id)
        XCTAssertNil(vm.pendingConfirmation)
    }

    func test_undo_goal_reverts_score_and_history() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        let eventCount = vm.matchEvents.count

        XCTAssertTrue(vm.undoLastUserEvent())
        XCTAssertEqual(vm.currentMatch?.homeScore, 0)
        XCTAssertEqual(vm.matchEvents.count, eventCount - 1)
        XCTAssertNil(vm.pendingConfirmation)
    }

    func test_recordSubstitutions_usesSingleFrozenSnapshotAndIncrementsCount() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.startMatch()

        vm.matchTime = "12:34"
        vm.currentPeriod = 2

        let substitutions = [
            SubstitutionDetails(playerOut: 4, playerIn: 12, playerOutName: nil, playerInName: nil),
            SubstitutionDetails(playerOut: 7, playerIn: 15, playerOutName: nil, playerInName: nil)
        ]

        vm.recordSubstitutions(team: .home, substitutions: substitutions)

        let recorded = vm.matchEvents.suffix(2)
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(vm.currentMatch?.homeSubs, 2)
        XCTAssertNil(vm.pendingConfirmation)

        let first = recorded[recorded.startIndex]
        let second = recorded[recorded.index(after: recorded.startIndex)]

        XCTAssertEqual(first.matchTime, "12:34")
        XCTAssertEqual(second.matchTime, "12:34")
        XCTAssertEqual(first.period, 2)
        XCTAssertEqual(second.period, 2)
        XCTAssertEqual(first.timestamp, second.timestamp)
        XCTAssertEqual(first.actualTime, second.actualTime)

        switch first.eventType {
        case let .substitution(details):
            XCTAssertEqual(details.playerOut, 4)
            XCTAssertEqual(details.playerIn, 12)
        default:
            XCTFail("Expected first event to be substitution")
        }

        switch second.eventType {
        case let .substitution(details):
            XCTAssertEqual(details.playerOut, 7)
            XCTAssertEqual(details.playerIn, 15)
        default:
            XCTFail("Expected second event to be substitution")
        }
    }

    func test_recordSubstitutions_filtersEmptyEntries() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.startMatch()

        vm.recordSubstitutions(
            team: .away,
            substitutions: [
                SubstitutionDetails(playerOut: nil, playerIn: nil, playerOutName: nil, playerInName: nil),
                SubstitutionDetails(playerOut: 6, playerIn: 14, playerOutName: nil, playerInName: nil)
            ])

        XCTAssertEqual(vm.currentMatch?.awaySubs, 1)
        guard let last = vm.matchEvents.last else {
            return XCTFail("Expected a recorded substitution")
        }

        switch last.eventType {
        case let .substitution(details):
            XCTAssertEqual(details.playerOut, 6)
            XCTAssertEqual(details.playerIn, 14)
        default:
            XCTFail("Expected substitution event")
        }
    }

    func test_substitutionDisplayDescription_usesNamesAndNumbersWhenAvailable() {
        let details = SubstitutionDetails(
            playerOut: 4,
            playerIn: nil,
            playerOutName: "Alex",
            playerInName: "Jamie"
        )
        let event = MatchEventRecord(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1),
            actualTime: Date(timeIntervalSince1970: 1),
            matchTime: "12:34",
            period: 1,
            eventType: .substitution(details),
            team: .home,
            details: .substitution(details)
        )

        XCTAssertEqual(event.displayDescription, "Substitution - #4 Alex -> Jamie")
    }

    func test_undo_without_events_returns_false() {
        let vm = MatchViewModel()
        XCTAssertFalse(vm.undoLastUserEvent())
    }

    func test_end_current_period_records_period_end_event() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 10, periods: 2, halfTimeLength: 1, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        let initialCount = vm.matchEvents.count

        vm.endCurrentPeriod()

        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1)
        XCTAssertGreaterThan(vm.matchEvents.count, initialCount)
        XCTAssertFalse(vm.isHalfTime)
        XCTAssertTrue(vm.waitingForHalfTimeStart)
    }

    func test_natural_period_expiry_enters_pending_boundary_state_and_requires_manual_end() async throws {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.currentMatch = Match(
            duration: 2,
            numberOfPeriods: 2,
            halfTimeLength: 1,
            hasExtraTime: false,
            hasPenalties: false
        )

        vm.startMatch()

        let reachedBoundary = await waitUntil(timeoutSeconds: 3) {
            vm.pendingPeriodBoundaryDecision == .firstHalf
        }
        XCTAssertTrue(reachedBoundary, "Expected boundary callback to enter the pending boundary-decision state")
        XCTAssertFalse(vm.isMatchInProgress)
        XCTAssertFalse(vm.isPaused)
        XCTAssertFalse(vm.isHalfTime)
        XCTAssertFalse(vm.waitingForHalfTimeStart)
        XCTAssertEqual(vm.pendingPeriodBoundaryDecision, .firstHalf)
        XCTAssertEqual(periodEndCount(in: vm, period: 1), 0)
        XCTAssertEqual(lifecycleHaptics.playedCues, [.periodBoundaryReached(.firstHalf)])

        let boundaryMatchTime = parseMMSS(vm.matchTime)
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let laterMatchTime = parseMMSS(vm.matchTime)
        XCTAssertGreaterThan(laterMatchTime, boundaryMatchTime, "Match timer should continue after boundary signal")

        let cancelCountBeforeManualEnd = lifecycleHaptics.cancelCount
        vm.endCurrentPeriod()
        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1, "Manual end should not duplicate periodEnd")
        XCTAssertEqual(lifecycleHaptics.playedCues, [.periodBoundaryReached(.firstHalf)])
        XCTAssertEqual(lifecycleHaptics.cancelCount, cancelCountBeforeManualEnd + 1)
        XCTAssertNil(vm.pendingPeriodBoundaryDecision)
        XCTAssertFalse(vm.isHalfTime)
        XCTAssertTrue(vm.waitingForHalfTimeStart)
    }

    func test_end_current_period_does_not_duplicate_period_end_when_later_events_exist() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 10, periods: 2, halfTimeLength: 1, hasExtraTime: false, hasPenalties: false)
        vm.startMatch()

        vm.recordMatchEvent(.periodEnd(1))
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)

        vm.endCurrentPeriod()

        XCTAssertEqual(periodEndCount(in: vm, period: 1), 1)
    }

    func test_createMatch_resets_events_after_finalize() {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.createMatch()
        vm.startMatch()
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        XCTAssertFalse(vm.matchEvents.isEmpty)

        vm.finalizeMatch()
        XCTAssertFalse(vm.matchEvents.isEmpty, "Finalize does not clear events by design")

        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()

        XCTAssertTrue(vm.matchEvents.isEmpty, "Starting a new match should clear prior events")
        XCTAssertEqual(vm.currentPeriod, 1)
        XCTAssertFalse(vm.isMatchInProgress)
        XCTAssertNil(vm.pendingConfirmation)
    }

    func test_startHalfTimeManually_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.currentMatch = Match(duration: 90, numberOfPeriods: 2, halfTimeLength: 15)
        vm.waitingForHalfTimeStart = true

        vm.startHalfTimeManually()

        XCTAssertEqual(lifecycleHaptics.cancelCount, 1)
        XCTAssertTrue(vm.isHalfTime)
    }

    func test_resetMatch_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.startMatch()

        let cancelCountBeforeReset = lifecycleHaptics.cancelCount
        vm.resetMatch()

        XCTAssertEqual(lifecycleHaptics.cancelCount, cancelCountBeforeReset + 1)
    }

    func test_beginPenaltiesIfNeeded_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.currentMatch = Match(duration: 90, numberOfPeriods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: true)
        vm.waitingForPenaltiesStart = true
        vm.isMatchInProgress = true

        vm.beginPenaltiesIfNeeded()

        XCTAssertEqual(lifecycleHaptics.cancelCount, 1)
        XCTAssertTrue(vm.penaltyShootoutActive)
        XCTAssertFalse(vm.waitingForPenaltiesStart)
    }

    func test_endPenaltiesAndProceed_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.currentMatch = Match(duration: 90, numberOfPeriods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: true)
        XCTAssertTrue(vm.startPenalties(withFirstKicker: .home))

        let cancelCountBeforeEndingPenalties = lifecycleHaptics.cancelCount
        vm.endPenaltiesAndProceed()

        XCTAssertEqual(lifecycleHaptics.cancelCount, cancelCountBeforeEndingPenalties + 1)
        XCTAssertFalse(vm.penaltyShootoutActive)
        XCTAssertTrue(vm.isFullTime)
    }

    func test_abandonMatch_cancelsPendingLifecyclePlayback() {
        let lifecycleHaptics = MatchLifecycleHapticsSpy()
        let vm = MatchViewModel(lifecycleHaptics: lifecycleHaptics)
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        vm.startMatch()

        let cancelCountBeforeAbandon = lifecycleHaptics.cancelCount
        vm.abandonMatch()

        XCTAssertEqual(lifecycleHaptics.cancelCount, cancelCountBeforeAbandon + 1)
        XCTAssertTrue(vm.isFullTime)
        XCTAssertFalse(vm.isMatchInProgress)
    }
}

private extension MatchViewModel_EventsAndStoppageTests {
    func periodEndCount(in vm: MatchViewModel, period: Int) -> Int {
        vm.matchEvents.reduce(into: 0) { count, event in
            if case .periodEnd(let endedPeriod) = event.eventType, endedPeriod == period {
                count += 1
            }
        }
    }

    func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () -> Bool) async -> Bool {
        let timeoutNanos = UInt64(timeoutSeconds * 1_000_000_000)
        let stepNanos: UInt64 = 100_000_000
        var elapsedNanos: UInt64 = 0

        while elapsedNanos < timeoutNanos {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: stepNanos)
            elapsedNanos += stepNanos
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
