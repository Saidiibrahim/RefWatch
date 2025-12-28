import Testing
@testable import RefWatchiOS

@Suite("ScheduledMatch.Status Decoder")
struct ScheduledMatchStatusDecoderTests {

    @Test("Maps database snake_case to Swift camelCase")
    func mapsSnakeCaseToCamelCase() {
        #expect(ScheduledMatch.Status(fromDatabase: "scheduled") == .scheduled)
        #expect(ScheduledMatch.Status(fromDatabase: "in_progress") == .inProgress)
        #expect(ScheduledMatch.Status(fromDatabase: "completed") == .completed)
        #expect(ScheduledMatch.Status(fromDatabase: "canceled") == .canceled)
    }

    @Test("Falls back to .scheduled for unknown values")
    func fallsBackForUnknown() {
        #expect(ScheduledMatch.Status(fromDatabase: "unknown_status") == .scheduled)
        #expect(ScheduledMatch.Status(fromDatabase: "") == .scheduled)
        #expect(ScheduledMatch.Status(fromDatabase: "INVALID") == .scheduled)
    }

    @Test("Encodes to database snake_case format")
    func encodesToDatabaseFormat() {
        #expect(ScheduledMatch.Status.scheduled.databaseValue == "scheduled")
        #expect(ScheduledMatch.Status.inProgress.databaseValue == "in_progress")
        #expect(ScheduledMatch.Status.completed.databaseValue == "completed")
        #expect(ScheduledMatch.Status.canceled.databaseValue == "canceled")
    }

    @Test("Round-trip conversion preserves values")
    func roundTripConversion() {
        let cases: [(String, ScheduledMatch.Status)] = [
            ("scheduled", .scheduled),
            ("in_progress", .inProgress),
            ("completed", .completed),
            ("canceled", .canceled)
        ]

        for (dbValue, swiftEnum) in cases {
            let decoded = ScheduledMatch.Status(fromDatabase: dbValue)
            #expect(decoded == swiftEnum)
            #expect(decoded.databaseValue == dbValue)
        }
    }
}
