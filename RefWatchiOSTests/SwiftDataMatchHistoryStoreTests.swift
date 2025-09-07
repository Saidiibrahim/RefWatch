import XCTest
import SwiftData
import RefWatchCore
@testable import RefWatchiOS

final class SwiftDataMatchHistoryStoreTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([CompletedMatchRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testSaveAndLoad_roundTrip() throws {
        let container = try makeContainer()
        let store = SwiftDataMatchHistoryStore(container: container, importJSONOnFirstRun: false)
        let m = Match(homeTeam: "Home", awayTeam: "Away")
        let snap = CompletedMatch(match: m, events: [])

        try store.save(snap)
        let all = try store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.match.homeTeam, "Home")
    }

    func testUpsert_dedupesById() throws {
        let container = try makeContainer()
        let store = SwiftDataMatchHistoryStore(container: container, importJSONOnFirstRun: false)
        var m = Match(homeTeam: "Home", awayTeam: "Away")
        var snap = CompletedMatch(match: m, events: [])
        try store.save(snap)

        // Save again with same id but different score
        m.homeScore = 2
        snap = CompletedMatch(id: snap.id, completedAt: snap.completedAt, match: m, events: snap.events, schemaVersion: snap.schemaVersion)
        try store.save(snap)

        let all = try store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.match.homeScore, 2)
    }

    func testOwnerAssignment_whenAuthPresent_setsOwnerId() throws {
        struct TestAuth: AuthenticationProviding { let state: AuthState; var currentUserId: String? { if case let .signedIn(userId, _) = state { return userId } else { return nil } } }
        let container = try makeContainer()
        let auth = TestAuth(state: .signedIn(userId: "u1", displayName: "Test"))
        let store = SwiftDataMatchHistoryStore(container: container, auth: auth, importJSONOnFirstRun: false)
        let m = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: m, events: [])
        try store.save(snap)
        let all = try store.loadAll()
        XCTAssertEqual(all.first?.ownerId, "u1")
    }

    func testLoadAll_isBoundedByDefaultLimit() throws {
        let container = try makeContainer()
        let store = SwiftDataMatchHistoryStore(container: container, importJSONOnFirstRun: false)
        // Insert more than the default fetch limit (200)
        for i in 0..<300 {
            var m = Match(homeTeam: "H\(i)", awayTeam: "A\(i)")
            m.homeScore = i
            let snap = CompletedMatch(match: m, events: [])
            try store.save(snap)
        }
        let all = try store.loadAll()
        XCTAssertLessThanOrEqual(all.count, 200)
        XCTAssertGreaterThan(all.count, 0)
    }

    func testLoadBefore_returnsDescendingPages() throws {
        let container = try makeContainer()
        let store = SwiftDataMatchHistoryStore(container: container, importJSONOnFirstRun: false)
        let now = Date()
        // Seed 15 snapshots with distinct completion times
        for i in 0..<15 {
            var m = Match(homeTeam: "H", awayTeam: "A")
            m.homeScore = i
            let ts = now.addingTimeInterval(TimeInterval(-i * 60)) // newer first
            let snap = CompletedMatch(id: UUID(), completedAt: ts, match: m, events: [])
            try store.save(snap)
        }
        let first = try store.loadBefore(completedAt: nil, limit: 5)
        XCTAssertEqual(first.count, 5)
        XCTAssertTrue(first[0].completedAt > first[1].completedAt)
        let cursor = first.last!.completedAt
        let second = try store.loadBefore(completedAt: cursor, limit: 5)
        XCTAssertEqual(second.count, 5)
        XCTAssertTrue(second[0].completedAt > second[1].completedAt)
        // Ensure strictly older than cursor
        XCTAssertTrue(second.first!.completedAt < cursor)
    }
}
