import XCTest
import RefWatchCore
@testable import RefZoneiOS

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

    func testHandleCompletedMatch_savesOnMainActor() async {
        class MainActorStore: MatchHistoryStoring {
            let exp: XCTestExpectation
            init(exp: XCTestExpectation) { self.exp = exp }
            func loadAll() throws -> [CompletedMatch] { [] }
            func save(_ match: CompletedMatch) throws {
                // Expect to run on main thread due to @MainActor hop in client
                XCTAssertTrue(Thread.isMainThread)
                exp.fulfill()
            }
            func delete(id: UUID) throws {}
            func wipeAll() throws {}
        }

        let exp = expectation(description: "save on main")
        let store = MainActorStore(exp: exp)
        let client = IOSConnectivitySyncClient(history: store, auth: NoopAuth())
        let match = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: match, events: [])

        // Call from a background queue to ensure hop
        DispatchQueue.global().async {
            client.handleCompletedMatch(snap)
        }

        wait(for: [exp], timeout: 2.0)
    }
}
