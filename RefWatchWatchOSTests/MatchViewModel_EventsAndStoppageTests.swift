//
//  MatchViewModel_EventsAndStoppageTests.swift
//  RefWatch Watch AppTests
//

import Foundation
import Testing
@testable import RefZone_Watch_App

private func parseMMSS(_ s: String) -> Int {
    let comps = s.split(separator: ":")
    guard comps.count == 2,
          let mm = Int(comps[0]),
          let ss = Int(comps[1]) else { return 0 }
    return mm * 60 + ss
}

struct MatchViewModel_EventsAndStoppageTests {

    @Test func test_event_order_after_start_and_goal() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        #expect(vm.matchEvents.count >= 2)
        if vm.matchEvents.count >= 2 {
            switch vm.matchEvents[0].eventType {
            case .kickOff: break
            default: Issue.record("First event should be kickOff")
            }
            switch vm.matchEvents[1].eventType {
            case .periodStart(let p):
                #expect(p == 1)
            default:
                Issue.record("Second event should be periodStart(1)")
            }
        }

        // Record a goal and check it appends in order
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        let last = vm.matchEvents.last
        #expect(last != nil)
        if let last {
            switch last.eventType {
            case .goal(let details):
                #expect(details.goalType == .regular)
                #expect(last.team == .home)
            default:
                Issue.record("Last event should be a regular goal for home")
            }
        }
    }

    @Test func test_regular_and_own_goal_scoring_updates_correct_side() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.startMatch()

        // Regular goal: home scores
        vm.recordGoal(team: .home, goalType: .regular, playerNumber: 9)
        #expect(vm.currentMatch?.homeScore == 1)
        #expect(vm.currentMatch?.awayScore == 0)

        // Own goal: in UI, own goal from home team maps to AWAY scoring
        // Here we simulate that by passing .away to the VM (as TeamDetailsView does)
        vm.recordGoal(team: .away, goalType: .ownGoal, playerNumber: 5)
        #expect(vm.currentMatch?.homeScore == 1)
        #expect(vm.currentMatch?.awayScore == 1)
    }

    @Test func test_stoppage_accumulates_across_pauses() async throws {
        let vm = MatchViewModel()
        vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)

        vm.startMatch()
        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_200_000_000) // ~1.2s
        vm.resumeMatch()
        let first = parseMMSS(vm.formattedStoppageTime)
        #expect(first >= 1)

        vm.pauseMatch()
        try await Task.sleep(nanoseconds: 1_100_000_000) // ~1.1s
        vm.resumeMatch()
        let second = parseMMSS(vm.formattedStoppageTime)
        #expect(second >= 2)
    }
}
