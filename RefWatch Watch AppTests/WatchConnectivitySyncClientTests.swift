import Foundation
import Testing
@testable import RefWatch_Watch_App
import RefWatchCore

final class MockWCSession: WCSessioning {
    var isReachable: Bool
    var sendShouldError: Bool
    private(set) var transferred: [[String: Any]] = []

    init(isReachable: Bool, sendShouldError: Bool) {
        self.isReachable = isReachable
        self.sendShouldError = sendShouldError
    }

    func activate() {}

    func sendMessage(_ message: [String : Any], errorHandler: @escaping (Error) -> Void) {
        if sendShouldError {
            errorHandler(NSError(domain: "test", code: -1))
        }
    }

    func transferUserInfo(_ userInfo: [String : Any]) {
        transferred.append(userInfo)
    }
}

struct WatchConnectivitySyncClientTests {
    @Test
    func test_sendMessage_error_fallsBackTo_transferUserInfo_and_postsDiagnostic() async throws {
        let mock = MockWCSession(isReachable: true, sendShouldError: true)
        let client = WatchConnectivitySyncClient(session: mock)

        var observed = false
        let token = NotificationCenter.default.addObserver(forName: .syncFallbackOccurred, object: nil, queue: .main) { _ in
            observed = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let match = Match(homeTeam: "H", awayTeam: "A")
        let snap = CompletedMatch(match: match, events: [])
        client.sendCompletedMatch(snap)
        // Allow async error handler to run
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(mock.transferred.count == 1)
        #expect(observed == true)
    }
}

