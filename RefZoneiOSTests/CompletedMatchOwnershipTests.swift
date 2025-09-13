import XCTest
import RefWatchCore

final class CompletedMatchOwnershipTests: XCTestCase {
    private struct TestAuth: AuthenticationProviding {
        let state: AuthState
        var currentUserId: String? {
            switch state {
            case let .signedIn(userId, _): return userId
            case .signedOut: return nil
            }
        }
    }

    func testAttachingOwner_setsOwnerWhenMissing() {
        let m = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: m, events: [])
        let auth = TestAuth(state: .signedIn(userId: "u123", displayName: "Alex"))
        let out = snap.attachingOwnerIfMissing(using: auth)
        XCTAssertEqual(out.ownerId, "u123")
    }

    func testAttachingOwner_keepsExistingOwner() {
        let m = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: m, events: [], ownerId: "keep")
        let auth = TestAuth(state: .signedIn(userId: "u123", displayName: "Alex"))
        let out = snap.attachingOwnerIfMissing(using: auth)
        XCTAssertEqual(out.ownerId, "keep")
    }
}

