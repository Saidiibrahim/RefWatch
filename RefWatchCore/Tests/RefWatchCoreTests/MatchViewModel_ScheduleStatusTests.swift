//
//  MatchViewModel_ScheduleStatusTests.swift
//  RefWatchCoreTests
//
//  Integration tests for MatchViewModel schedule status updating
//

import Testing
import Foundation
@testable import RefWatchCore

@Suite("MatchViewModel Schedule Status Integration")
@MainActor
struct MatchViewModelScheduleStatusTests {

    @Test("finalizeMatch calls updater with correct schedule ID")
    func finalizeMatchCallsUpdater() async throws {
        // Given: A ViewModel with a spy updater
        let mockHistory = InMemoryHistory()
        let spyUpdater = SpyScheduleStatusUpdater()
        let vm = MatchViewModel(
            history: mockHistory,
            scheduleStatusUpdater: spyUpdater
        )

        // And: A match is created and in progress
        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()
        // Link a schedule id, since updater expects schedule IDs
        let scheduledId = UUID()
        if var m = vm.currentMatch { m.scheduledMatchId = scheduledId; vm.currentMatch = m }

        // When: The match is finalized
        vm.finalizeMatch()

        // Then: The updater should be called with the match ID
        // Give a small delay for the Task to execute
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        #expect(spyUpdater.markScheduleCompletedCalled == true)
        #expect(spyUpdater.lastMarkedId == scheduledId)
        #expect(spyUpdater.callCount == 1)
    }

    @Test("finalizeMatch works without updater (watchOS scenario)")
    func finalizeMatchWorksWithoutUpdater() async throws {
        // Given: A ViewModel without an updater (watchOS scenario)
        let mockHistory = InMemoryHistory()
        let vm = MatchViewModel(
            history: mockHistory,
            scheduleStatusUpdater: nil
        )

        // And: A match is created and in progress
        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()

        // When: The match is finalized
        if var m = vm.currentMatch { m.scheduledMatchId = UUID(); vm.currentMatch = m }
        vm.finalizeMatch()

        // Then: No crash should occur and match should be saved
        #expect(mockHistory.saved.count == 1)
        #expect(vm.currentMatch == nil)
    }

    @Test("finalizeMatch calls updater only once per finalization")
    func finalizeMatchCallsUpdaterOnce() async throws {
        // Given: A ViewModel with a spy updater
        let mockHistory = InMemoryHistory()
        let spyUpdater = SpyScheduleStatusUpdater()
        let vm = MatchViewModel(
            history: mockHistory,
            scheduleStatusUpdater: spyUpdater
        )

        // And: Multiple matches are created and finalized
        for _ in 1...3 {
            vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
            vm.createMatch()
            if var m = vm.currentMatch { m.scheduledMatchId = UUID(); vm.currentMatch = m }
            vm.finalizeMatch()

            // Wait for async Task to complete
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Then: The updater should be called exactly 3 times (once per match)
        #expect(spyUpdater.callCount == 3)
    }

    @Test("finalizeMatch does not call updater when history save fails")
    func finalizeMatchSkipsUpdaterOnHistoryFailure() async throws {
        // Given: A ViewModel with a failing history and a spy updater
        let failingHistory = FailingHistory()
        let spyUpdater = SpyScheduleStatusUpdater()
        let vm = MatchViewModel(
            history: failingHistory,
            scheduleStatusUpdater: spyUpdater
        )

        // And: A match is created
        vm.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
        vm.createMatch()

        // When: The match is finalized
        vm.finalizeMatch()

        // Wait for potential async Task
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: The updater should NOT be called because history save failed
        #expect(spyUpdater.markScheduleCompletedCalled == false)
        #expect(vm.lastPersistenceError != nil)
    }
}

// MARK: - Test Helpers

@MainActor
private final class InMemoryHistory: MatchHistoryStoring {
    private(set) var saved: [CompletedMatch] = []

    func loadAll() throws -> [CompletedMatch] { saved }
    func save(_ match: CompletedMatch) throws { saved.append(match) }
    func delete(id: UUID) throws { saved.removeAll { $0.id == id } }
    func wipeAll() throws { saved.removeAll() }
}

@MainActor
private final class FailingHistory: MatchHistoryStoring {
    func loadAll() throws -> [CompletedMatch] { [] }
    func save(_ match: CompletedMatch) throws {
        throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated save failure"])
    }
    func delete(id: UUID) throws { }
    func wipeAll() throws { }
}

@MainActor
private final class SpyScheduleStatusUpdater: MatchScheduleStatusUpdating {
    private(set) var markScheduleInProgressCalled = false
    private(set) var markScheduleCompletedCalled = false
    private(set) var lastMarkedId: UUID?
    private(set) var lastInProgressId: UUID?
    private(set) var inProgressCallCount = 0
    private(set) var callCount = 0

    func markScheduleInProgress(scheduledId: UUID) async throws {
        markScheduleInProgressCalled = true
        lastInProgressId = scheduledId
        inProgressCallCount += 1
    }

    func markScheduleCompleted(scheduledId: UUID) async throws {
        markScheduleCompletedCalled = true
        lastMarkedId = scheduledId
        callCount += 1
    }
}
