//
//  ExtraTimeAndPenaltiesTests.swift
//  RefWatch Watch AppTests
//

import Testing
@testable import RefWatch_Watch_App
@testable import RefWatchCore

@MainActor
struct ExtraTimeAndPenaltiesTests {

    @Test
    func test_transition_to_ET_when_hasExtraTime() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: false)

        vm.startMatch()
        vm.startNextPeriod() // move to second half
        vm.endCurrentPeriod() // end regulation

        #expect(vm.waitingForET1Start == true)
    }

    @Test
    func test_ET_period_start_events_and_transitions() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: false)

        vm.startMatch()
        vm.startNextPeriod()
        vm.endCurrentPeriod() // end regulation -> ET1 waiting
        #expect(vm.waitingForET1Start == true)

        vm.startExtraTimeFirstHalfManually()
        #expect(vm.currentPeriod == 3)
        // last event should be periodStart(3)
        if let last = vm.matchEvents.last {
            switch last.eventType {
            case .periodStart(let p): #expect(p == 3)
            default: Issue.record("Expected periodStart(3) event")
            }
        } else {
            Issue.record("Expected at least one event after starting ET1")
        }

        vm.endCurrentPeriod() // end ET1 -> ET2 waiting
        #expect(vm.waitingForET2Start == true)

        vm.startExtraTimeSecondHalfManually()
        #expect(vm.currentPeriod == 4)
        if let last = vm.matchEvents.last {
            switch last.eventType {
            case .periodStart(let p): #expect(p == 4)
            default: Issue.record("Expected periodStart(4) event")
            }
        }
    }

    @Test
    func test_transition_to_penalties_after_et_when_hasPenalties() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
        vm.startMatch()
        vm.startNextPeriod()
        vm.endCurrentPeriod() // -> ET1 waiting
        vm.startExtraTimeFirstHalfManually()
        vm.endCurrentPeriod() // -> ET2 waiting
        vm.startExtraTimeSecondHalfManually()

        vm.endCurrentPeriod() // end ET2 -> penalties waiting
        #expect(vm.waitingForPenaltiesStart == true)
    }

    @Test
    func test_endCurrentPeriod_routes_to_ET1_when_hasExtraTime() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: false)
        // Simulate being at end of regulation second half
        vm.currentPeriod = 2
        vm.endCurrentPeriod()
        #expect(vm.waitingForET1Start == true)
    }

    @Test
    func test_endCurrentPeriod_routes_to_penalties_when_hasPenalties_after_ET2() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
        // Simulate being at end of ET2
        vm.currentPeriod = 4
        vm.endCurrentPeriod()
        #expect(vm.waitingForPenaltiesStart == true)
    }

    @Test
    func test_total_match_time_accumulates_correctly_in_ET2() async throws {
        let vm = MatchViewModel()
        // Custom tiny durations to make the test quick
        let match = Match(
            duration: TimeInterval(20), // two regulation periods of 10s each
            numberOfPeriods: 2,
            halfTimeLength: TimeInterval(5),
            extraTimeHalfLength: TimeInterval(5),
            hasExtraTime: true,
            hasPenalties: false
        )
        vm.currentMatch = match
        vm.waitingForET2Start = true
        vm.startExtraTimeSecondHalfManually() // sets currentPeriod = 4 and starts timer

        // After roughly 1s, accumulated should be >= 25s (10 + 10 + 5) 
        try await Task.sleep(nanoseconds: 1_100_000_000)
        let total = parseMMSS(vm.matchTime)
        #expect(total >= 25)
        #expect(total <= 27)
    }

    @Test
    func test_penalty_attempt_logging_and_tallies() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)

        // Simulate reaching penalties
        vm.waitingForPenaltiesStart = true
        vm.beginPenaltiesIfNeeded()
        #expect(vm.penaltyShootoutActive == true)
        #expect(vm.currentPeriod == 5)

        let priorCount = vm.matchEvents.count

        vm.recordPenaltyAttempt(team: .home, result: .scored)
        vm.recordPenaltyAttempt(team: .away, result: .missed)

        #expect(vm.homePenaltiesTaken == 1)
        #expect(vm.homePenaltiesScored == 1)
        #expect(vm.awayPenaltiesTaken == 1)
        #expect(vm.awayPenaltiesScored == 0)
        #expect(vm.homePenaltyResults.count == 1)
        #expect(vm.homePenaltyResults.first == .scored)
        #expect(vm.awayPenaltyResults.count == 1)
        #expect(vm.awayPenaltyResults.first == .missed)

        #expect(vm.matchEvents.count == priorCount + 3) // penaltiesStart + 2 attempts

        // End shootout
        vm.endPenaltiesAndProceed()
        #expect(vm.penaltyShootoutActive == false)
        #expect(vm.isFullTime == true)
    }

    @Test
    func test_penalties_next_team_and_early_win_detection() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
        vm.beginPenaltiesIfNeeded()

        // Default first kicker is home
        #expect(vm.nextPenaltyTeam == .home)

        // Sequence: H score, A miss, H score, A miss, H score, A miss, H score -> early decision for Home
        vm.recordPenaltyAttempt(team: .home, result: .scored)
        #expect(vm.nextPenaltyTeam == .away)
        vm.recordPenaltyAttempt(team: .away, result: .missed)
        #expect(vm.nextPenaltyTeam == .home)
        vm.recordPenaltyAttempt(team: .home, result: .scored)
        vm.recordPenaltyAttempt(team: .away, result: .missed)
        vm.recordPenaltyAttempt(team: .home, result: .scored)
        vm.recordPenaltyAttempt(team: .away, result: .missed)
        // Before last home kick, not decided yet (away could still tie)
        #expect(vm.isPenaltyShootoutDecided == false)
        vm.recordPenaltyAttempt(team: .home, result: .scored)

        // Now Home has 4, Away has 0 with 2 remaining -> early decision
        #expect(vm.isPenaltyShootoutDecided == true)
        #expect(vm.penaltyWinner == .home)
    }

    @Test
    func test_sudden_death_decision_after_equal_attempts() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
        vm.beginPenaltiesIfNeeded()

        // Make it 4-4 after 5 each
        for i in 0..<5 {
            if i < 4 { vm.recordPenaltyAttempt(team: .home, result: .scored) } else { vm.recordPenaltyAttempt(team: .home, result: .missed) }
            if i < 4 { vm.recordPenaltyAttempt(team: .away, result: .scored) } else { vm.recordPenaltyAttempt(team: .away, result: .missed) }
        }
        #expect(vm.isPenaltyShootoutDecided == false)

        // Sudden death: Home scores (not decided yet, away must take)
        vm.recordPenaltyAttempt(team: .home, result: .scored)
        #expect(vm.isPenaltyShootoutDecided == false)
        // Away misses -> decided
        vm.recordPenaltyAttempt(team: .away, result: .missed)
        #expect(vm.isPenaltyShootoutDecided == true)
        #expect(vm.penaltyWinner == .home)
    }

    @Test
    func test_penalty_event_contains_round_number_and_first_kicker_setting() async throws {
        let vm = MatchViewModel()
        vm.beginPenaltiesIfNeeded()

        // Change first kicker to away and verify next team
        vm.setPenaltyFirstKicker(.away)
        #expect(vm.nextPenaltyTeam == .away)

        // Record one away kick; event should have round 1
        vm.recordPenaltyAttempt(team: .away, result: .scored)
        if let last = vm.matchEvents.last {
            switch last.eventType {
            case .penaltyAttempt(let details):
                #expect(details.round == 1)
            default:
                Issue.record("Expected penaltyAttempt event with round number")
            }
        } else {
            Issue.record("Expected an event after penalty attempt")
        }
    }

    @Test
    func test_isSuddenDeathActive_after_five_each() async throws {
        let vm = MatchViewModel()
        vm.beginPenaltiesIfNeeded()

        for _ in 0..<5 {
            vm.recordPenaltyAttempt(team: .home, result: .scored)
            vm.recordPenaltyAttempt(team: .away, result: .scored)
        }
        #expect(vm.isSuddenDeathActive == true)
    }

    @Test
    func test_penalty_initial_rounds_configurable() async throws {
        let vm = MatchViewModel()
        // Configure a match with 3 initial rounds for shootout
        vm.penaltyInitialRounds = 3
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
        vm.beginPenaltiesIfNeeded()

        for _ in 0..<3 {
            vm.recordPenaltyAttempt(team: .home, result: .scored)
            vm.recordPenaltyAttempt(team: .away, result: .scored)
        }
        // After 3 each, sudden death should be active
        #expect(vm.isSuddenDeathActive == true)
    }
}
