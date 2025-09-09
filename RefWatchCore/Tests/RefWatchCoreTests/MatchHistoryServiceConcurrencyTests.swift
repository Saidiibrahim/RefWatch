import XCTest
@testable import RefWatchCore

final class MatchHistoryServiceConcurrencyTests: XCTestCase {

    func test_concurrent_saves_are_thread_safe_and_ordered() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let svc = MatchHistoryService(baseDirectory: tmp)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    var match = Match(homeTeam: "H\(i)", awayTeam: "A\(i)")
                    match.homeScore = i
                    let e = MatchEventRecord(matchTime: "00:00", period: 1, eventType: .kickOff, details: .general)
                    let cm = CompletedMatch(
                        completedAt: Date(timeIntervalSince1970: TimeInterval(i)),
                        match: match,
                        events: [e]
                    )
                    await MainActor.run { try? svc.save(cm) }
                }
            }
        }

        let loaded = try await svc.loadAll()
        XCTAssertEqual(loaded.count, 50)
        XCTAssertEqual(loaded.first?.match.homeScore, 49)
        XCTAssertEqual(loaded.last?.match.homeScore, 0)
    }

    func test_loadRecent_returns_limited_sorted_list() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let svc = MatchHistoryService(baseDirectory: tmp)

        for i in 0..<10 {
            let e = MatchEventRecord(matchTime: "00:00", period: 1, eventType: .kickOff, details: .general)
            let cm = CompletedMatch(
                completedAt: Date(timeIntervalSince1970: TimeInterval(i)),
                match: Match(homeTeam: "H\(i)", awayTeam: "A\(i)"),
                events: [e]
            )
            try await svc.save(cm)
        }

        let recent = await svc.loadRecent(3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent[0].match.homeTeam, "H9")
        XCTAssertEqual(recent[1].match.homeTeam, "H8")
        XCTAssertEqual(recent[2].match.homeTeam, "H7")
    }
}
