//
//  MatchHistoryServiceTests.swift
//  RefWatch Watch AppTests
//

import Foundation
import Testing
@testable import RefWatch_Watch_App

struct MatchHistoryServiceTests {

    @Test
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

        #expect(loaded.count == 1)
        #expect(loaded.first?.match.homeTeam == "Alpha")
        #expect(loaded.first?.match.homeScore == 2)
        #expect(loaded.first?.events.first?.matchTime == "00:00")
    }

    @Test
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
        #expect(loaded.count == 2)

        try svc.delete(id: one.id)
        loaded = try svc.loadAll()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == two.id)
    }
}

