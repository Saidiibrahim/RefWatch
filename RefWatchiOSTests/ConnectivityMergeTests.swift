import XCTest
import RefWatchCore
@testable import RefWatchiOS

final class ConnectivityMergeTests: XCTestCase {
    private final class InMemoryStore: MatchHistoryStoring {
        var items: [CompletedMatch] = []
        func loadAll() throws -> [CompletedMatch] { items }
        func save(_ match: CompletedMatch) throws { if let idx = items.firstIndex(where: { $0.id == match.id }) { items[idx] = match } else { items.append(match) } }
        func delete(id: UUID) throws { items.removeAll { $0.id == id } }
        func wipeAll() throws { items.removeAll() }
    }

    func testHandleCompletedMatch_insertsAndDedupes() {
        let store = InMemoryStore()
        let client = IOSConnectivitySyncClient(history: store, auth: NoopAuth())
        let match = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: match, events: [])

        client.handleCompletedMatch(snap)
        XCTAssertEqual((try? store.loadAll())?.count, 1)

        // Send same id again with different score
        var updated = match
        updated.homeScore = 3
        let snap2 = CompletedMatch(id: snap.id, completedAt: snap.completedAt, match: updated, events: snap.events, schemaVersion: snap.schemaVersion)
        client.handleCompletedMatch(snap2)
        XCTAssertEqual((try? store.loadAll())?.count, 1)
        XCTAssertEqual((try? store.loadAll())?.first?.match.homeScore, 3)
    }
}

