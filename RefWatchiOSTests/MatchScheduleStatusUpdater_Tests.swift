//
//  MatchScheduleStatusUpdater_Tests.swift
//  RefWatchiOSTests
//
//  Unit tests for MatchScheduleStatusUpdater
//

import Testing
import Foundation
import Combine
@testable import RefWatchiOS

@Suite("MatchScheduleStatusUpdater")
@MainActor
struct MatchScheduleStatusUpdaterTests {

    @Test("Marks existing schedule as completed")
    func marksExistingScheduleCompleted() async throws {
        // Given: A schedule store with a scheduled match
        let scheduleId = UUID()
        let schedule = ScheduledMatch(
            id: scheduleId,
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .scheduled
        )
        let mockStore = MockScheduleStore(schedules: [schedule])
        let updater = MatchScheduleStatusUpdater(scheduleStore: mockStore)

        // When: Marking the schedule as completed
        try await updater.markScheduleCompleted(scheduledId: scheduleId)

        // Then: The schedule should be saved with completed status
        #expect(mockStore.saveCalled == true)
        #expect(mockStore.lastSavedSchedule?.id == scheduleId)
        #expect(mockStore.lastSavedSchedule?.status == .completed)
    }

    @Test("Handles missing schedule gracefully")
    func handlesMissingSchedule() async throws {
        // Given: An empty schedule store
        let mockStore = MockScheduleStore(schedules: [])
        let updater = MatchScheduleStatusUpdater(scheduleStore: mockStore)

        // When: Attempting to mark a non-existent schedule as completed
        let nonExistentId = UUID()
        try await updater.markScheduleCompleted(scheduledId: nonExistentId)

        // Then: No error should be thrown and no save should occur
        #expect(mockStore.saveCalled == false)
    }

    @Test("Updates correct schedule when multiple exist")
    func updatesCorrectSchedule() async throws {
        // Given: Multiple schedules in the store
        let targetId = UUID()
        let otherId = UUID()
        let schedules = [
            ScheduledMatch(
                id: otherId,
                homeTeam: "Team C",
                awayTeam: "Team D",
                kickoff: Date(),
                status: .scheduled
            ),
            ScheduledMatch(
                id: targetId,
                homeTeam: "Team A",
                awayTeam: "Team B",
                kickoff: Date(),
                status: .scheduled
            )
        ]
        let mockStore = MockScheduleStore(schedules: schedules)
        let updater = MatchScheduleStatusUpdater(scheduleStore: mockStore)

        // When: Marking one specific schedule as completed
        try await updater.markScheduleCompleted(scheduledId: targetId)

        // Then: Only the target schedule should be updated
        #expect(mockStore.lastSavedSchedule?.id == targetId)
        #expect(mockStore.lastSavedSchedule?.status == .completed)
        #expect(mockStore.lastSavedSchedule?.homeTeam == "Team A")
    }

    @Test("Preserves other schedule properties")
    func preservesOtherProperties() async throws {
        // Given: A schedule with various properties
        let scheduleId = UUID()
        let kickoffDate = Date()
        let schedule = ScheduledMatch(
            id: scheduleId,
            homeTeam: "Liverpool",
            awayTeam: "Manchester United",
            kickoff: kickoffDate,
            competition: "Premier League",
            notes: "Derby match",
            status: .scheduled
        )
        let mockStore = MockScheduleStore(schedules: [schedule])
        let updater = MatchScheduleStatusUpdater(scheduleStore: mockStore)

        // When: Marking the schedule as completed
        try await updater.markScheduleCompleted(scheduledId: scheduleId)

        // Then: All other properties should be preserved
        let saved = try #require(mockStore.lastSavedSchedule)
        #expect(saved.homeTeam == "Liverpool")
        #expect(saved.awayTeam == "Manchester United")
        #expect(saved.kickoff == kickoffDate)
        #expect(saved.competition == "Premier League")
        #expect(saved.notes == "Derby match")
        #expect(saved.status == .completed)
    }
}

// MARK: - Mock Schedule Store

@MainActor
private class MockScheduleStore: ScheduleStoring {
    private var schedules: [ScheduledMatch]
    private(set) var saveCalled = false
    private(set) var lastSavedSchedule: ScheduledMatch?

    init(schedules: [ScheduledMatch]) {
        self.schedules = schedules
    }

    func loadAll() -> [ScheduledMatch] {
        return schedules
    }

    func save(_ item: ScheduledMatch) throws {
        saveCalled = true
        lastSavedSchedule = item
        // Update in-memory store
        if let index = schedules.firstIndex(where: { $0.id == item.id }) {
            schedules[index] = item
        } else {
            schedules.append(item)
        }
    }

    func delete(id: UUID) throws {
        schedules.removeAll { $0.id == id }
    }

    func wipeAll() throws {
        schedules.removeAll()
    }

    var changesPublisher: AnyPublisher<[ScheduledMatch], Never> {
        Just(schedules).eraseToAnyPublisher()
    }

    func refreshFromRemote() async throws { }
}
