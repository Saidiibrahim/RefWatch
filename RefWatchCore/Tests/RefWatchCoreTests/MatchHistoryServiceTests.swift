import XCTest
@testable import RefWatchCore

final class MatchHistoryServiceTests: XCTestCase {

    func test_save_and_load_roundtrip() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let svc = MatchHistoryService(baseDirectory: tmp)

        var match = Match(homeTeam: "Alpha", awayTeam: "Beta")
        match.homeScore = 2
        match.awayScore = 1

        let kickoff = MatchEventRecord(
            matchTime: "00:00",
            period: 1,
            eventType: .kickOff,
            details: .general
        )

        let cm = CompletedMatch(
            completedAt: Date(timeIntervalSince1970: 1000),
            match: match,
            events: [kickoff]
        )

        try svc.save(cm)
        let loaded = try svc.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.match.homeTeam, "Alpha")
        XCTAssertEqual(loaded.first?.match.homeScore, 2)
        XCTAssertEqual(loaded.first?.events.first?.matchTime, "00:00")
    }

    func test_delete_removes_item() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let svc = MatchHistoryService(baseDirectory: tmp)
        let m = Match(homeTeam: "A", awayTeam: "B")
        let e = MatchEventRecord(matchTime: "00:00", period: 1, eventType: .kickOff, details: .general)
        let one = CompletedMatch(completedAt: Date(timeIntervalSince1970: 1000), match: m, events: [e])
        let two = CompletedMatch(completedAt: Date(timeIntervalSince1970: 2000), match: m, events: [e])

        try svc.save(one)
        try svc.save(two)
        var loaded = try svc.loadAll()
        XCTAssertEqual(loaded.count, 2)

        try svc.delete(id: one.id)
        loaded = try svc.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, two.id)
    }
}

