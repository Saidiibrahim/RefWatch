import XCTest
import RefWatchCore
@testable import RefWatchiOS

@MainActor
final class ConnectivityMergeTests: XCTestCase {
    @MainActor
    private final class InMemoryStore: MatchHistoryStoring {
        var items: [CompletedMatch] = []
        func loadAll() throws -> [CompletedMatch] { items }
        func save(_ match: CompletedMatch) throws { if let idx = items.firstIndex(where: { $0.id == match.id }) { items[idx] = match } else { items.append(match) } }
        func delete(id: UUID) throws { items.removeAll { $0.id == id } }
        func wipeAll() throws { items.removeAll() }
    }

    @MainActor
    private final class MutableAuth: AuthenticationProviding {
        private var backingState: AuthState

        init(state: AuthState = .signedOut) {
            self.backingState = state
        }

        var state: AuthState { backingState }

        var currentUserId: String? {
            if case let .signedIn(userId, _, _) = backingState { return userId }
            return nil
        }

        var currentEmail: String? {
            if case let .signedIn(_, email, _) = backingState { return email }
            return nil
        }

        var currentDisplayName: String? {
            if case let .signedIn(_, _, name) = backingState { return name }
            return nil
        }

        func signIn(userId: String, email: String? = nil, displayName: String? = nil) {
            backingState = .signedIn(userId: userId, email: email, displayName: displayName)
        }

        func signOut() {
            backingState = .signedOut
        }
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

    func testHandleCompletedMatch_whenSignedOut_queuesUntilSignedIn() async {
        let store = InMemoryStore()
        let auth = MutableAuth()
        let client = IOSConnectivitySyncClient(history: store, auth: auth)
        let match = Match(homeTeam: "Queue", awayTeam: "State")
        let snapshot = CompletedMatch(match: match, events: [])

        client.handleCompletedMatch(snapshot)
        XCTAssertTrue(store.items.isEmpty)

        auth.signIn(userId: "sup-queue", email: "queue@example.com")

        let flushExpectation = expectation(forNotification: .matchHistoryDidChange, object: nil)
        client.handleAuthState(.signedIn(userId: "sup-queue", email: "queue@example.com", displayName: nil))
        await fulfillment(of: [flushExpectation], timeout: 1.0)

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.ownerId, "sup-queue")
    }

    func testHandleCompletedMatch_afterSignOut_requiresReauthentication() async {
        let store = InMemoryStore()
        let auth = MutableAuth()
        let client = IOSConnectivitySyncClient(history: store, auth: auth)

        auth.signIn(userId: "sup-writer")
        let initialSaved = expectation(forNotification: .matchHistoryDidChange, object: nil)
        client.handleAuthState(.signedIn(userId: "sup-writer", email: nil, displayName: nil))
        client.handleCompletedMatch(CompletedMatch(match: Match(homeTeam: "First", awayTeam: "Match"), events: []))
        await fulfillment(of: [initialSaved], timeout: 1.0)

        XCTAssertEqual(store.items.count, 1)

        auth.signOut()
        client.handleAuthState(.signedOut)

        let queueExpectation = expectation(forNotification: .syncFallbackOccurred, object: nil) { note in
            guard let context = note.userInfo?["context"] as? String else { return false }
            return context == "ios.connectivity.queuedWhileSignedOut"
        }

        client.handleCompletedMatch(CompletedMatch(match: Match(homeTeam: "Queued", awayTeam: "Later"), events: []))
        XCTAssertEqual(store.items.count, 1)
        await fulfillment(of: [queueExpectation], timeout: 1.0)

        auth.signIn(userId: "sup-writer")
        let flushExpectation = expectation(forNotification: .matchHistoryDidChange, object: nil)
        client.handleAuthState(.signedIn(userId: "sup-writer", email: nil, displayName: nil))
        await fulfillment(of: [flushExpectation], timeout: 1.0)

        XCTAssertEqual(store.items.count, 2)
    }
}
