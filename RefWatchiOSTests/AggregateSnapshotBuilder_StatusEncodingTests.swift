//
//  AggregateSnapshotBuilder_StatusEncodingTests.swift
//  RefWatchiOSTests
//
//  Tests for schedule status encoding in aggregate sync payloads
//

import Testing
import Foundation
@testable import RefWatchiOS

@Suite("AggregateSnapshotBuilder Status Encoding")
struct AggregateSnapshotBuilderStatusEncodingTests {

    @Test("Encodes scheduled status as snake_case")
    func encodesScheduledAsSnakeCase() {
        // Given: A scheduled match
        let schedule = ScheduledMatch(
            id: UUID(),
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .scheduled
        )
        let builder = AggregateSnapshotBuilder()

        // When: Creating a payload from the schedule
        let payload = builder.makeSchedulePayload(from: schedule)

        // Then: Status should be encoded as snake_case "scheduled"
        #expect(payload.statusRaw == "scheduled")
    }

    @Test("Encodes inProgress status as snake_case")
    func encodesInProgressAsSnakeCase() {
        // Given: An in-progress match
        let schedule = ScheduledMatch(
            id: UUID(),
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .inProgress
        )
        let builder = AggregateSnapshotBuilder()

        // When: Creating a payload from the schedule
        let payload = builder.makeSchedulePayload(from: schedule)

        // Then: Status should be encoded as snake_case "in_progress" (NOT "inProgress")
        #expect(payload.statusRaw == "in_progress")
    }

    @Test("Encodes completed status as snake_case")
    func encodesCompletedAsSnakeCase() {
        // Given: A completed match
        let schedule = ScheduledMatch(
            id: UUID(),
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .completed
        )
        let builder = AggregateSnapshotBuilder()

        // When: Creating a payload from the schedule
        let payload = builder.makeSchedulePayload(from: schedule)

        // Then: Status should be encoded as snake_case "completed"
        #expect(payload.statusRaw == "completed")
    }

    @Test("Encodes canceled status as snake_case")
    func encodesCanceledAsSnakeCase() {
        // Given: A canceled match
        let schedule = ScheduledMatch(
            id: UUID(),
            homeTeam: "Team A",
            awayTeam: "Team B",
            kickoff: Date(),
            status: .canceled
        )
        let builder = AggregateSnapshotBuilder()

        // When: Creating a payload from the schedule
        let payload = builder.makeSchedulePayload(from: schedule)

        // Then: Status should be encoded as snake_case "canceled"
        #expect(payload.statusRaw == "canceled")
    }

    @Test("All status encodings match database format")
    func allStatusEncodingsMatchDatabaseFormat() {
        // Given: All possible schedule statuses
        let statuses: [ScheduledMatch.Status] = [
            .scheduled,
            .inProgress,
            .completed,
            .canceled
        ]
        let builder = AggregateSnapshotBuilder()

        for status in statuses {
            // When: Creating a payload for each status
            let schedule = ScheduledMatch(
                id: UUID(),
                homeTeam: "Team A",
                awayTeam: "Team B",
                kickoff: Date(),
                status: status
            )
            let payload = builder.makeSchedulePayload(from: schedule)

            // Then: Payload encoding should match the status's databaseValue
            #expect(
                payload.statusRaw == status.databaseValue,
                "Status \(status) should encode as '\(status.databaseValue)' but got '\(payload.statusRaw)'"
            )
        }
    }

    @Test("Round-trip encoding produces correct watch-side decoding")
    func roundTripEncodingProducesCorrectDecoding() {
        // Given: All possible schedule statuses
        let testCases: [(ScheduledMatch.Status, String)] = [
            (.scheduled, "scheduled"),
            (.inProgress, "in_progress"),
            (.completed, "completed"),
            (.canceled, "canceled")
        ]
        let builder = AggregateSnapshotBuilder()

        for (status, expectedEncoding) in testCases {
            // When: iOS encodes the status
            let schedule = ScheduledMatch(
                id: UUID(),
                homeTeam: "Team A",
                awayTeam: "Team B",
                kickoff: Date(),
                status: status
            )
            let payload = builder.makeSchedulePayload(from: schedule)

            // And: Watch decodes using fromDatabase (simulated)
            let decodedStatus = ScheduledMatch.Status(fromDatabase: payload.statusRaw)

            // Then: Round-trip should preserve the status
            #expect(
                payload.statusRaw == expectedEncoding,
                "iOS should encode \(status) as '\(expectedEncoding)'"
            )
            #expect(
                decodedStatus == status,
                "Watch should decode '\(payload.statusRaw)' back to \(status)"
            )
        }
    }
}
