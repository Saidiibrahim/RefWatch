//
//  MatchHistoryServiceConcurrencyTests.swift
//  RefWatch Watch AppTests
//

import Foundation
import Testing
@testable import RefWatch_Watch_App

struct MatchHistoryServiceConcurrencyTests {

    @Test
    func test_concurrent_saves_are_thread_safe_and_ordered() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let svc = MatchHistoryService(baseDirectory: tmp)

        // Save 50 snapshots concurrently
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
                    try? svc.save(cm)
                }
            }
        }

        let loaded = try svc.loadAll()
        #expect(loaded.count == 50)
        // Expect descending by completedAt (latest first)
        #expect(loaded.first?.match.homeScore == 49)
        #expect(loaded.last?.match.homeScore == 0)
    }

    @Test
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
            try svc.save(cm)
        }

        let recent = svc.loadRecent(3)
        #expect(recent.count == 3)
        #expect(recent[0].match.homeTeam == "H9")
        #expect(recent[1].match.homeTeam == "H8")
        #expect(recent[2].match.homeTeam == "H7")
    }
}

