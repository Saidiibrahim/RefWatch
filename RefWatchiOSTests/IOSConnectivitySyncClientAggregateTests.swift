import XCTest
@testable import RefWatchiOS
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
final class IOSConnectivitySyncClientAggregateTests: XCTestCase {
  func testAggregateDeltaProcessesAfterSignIn() throws {
    let history = MockHistoryStore()
    let auth = MutableAuth(state: .signedOut)
    let client = IOSConnectivitySyncClient(history: history, auth: auth)
    let envelope = makeEnvelope()

    let queuedExpectation = expectation(description: "delta queued while signed out")
    let queuedToken = NotificationCenter.default.addObserver(forName: .syncFallbackOccurred, object: nil, queue: .main) { note in
      if note.userInfo?["context"] as? String == "ios.aggregate.delta.queued" {
        queuedExpectation.fulfill()
      }
    }
    defer { NotificationCenter.default.removeObserver(queuedToken) }

    client.enqueueAggregateDelta(envelope)
    wait(for: [queuedExpectation], timeout: 1.0)

    let processedExpectation = expectation(description: "delta processed after sign-in")
    let handler = MockAggregateHandler { _ in
      processedExpectation.fulfill()
    }
    client.setAggregateDeltaHandler(handler)

    auth.updateState(.signedIn(userId: "user", email: nil, displayName: nil))
    client.handleAuthState(auth.state)

    wait(for: [processedExpectation], timeout: 2.0)
    XCTAssertEqual(handler.processed.count, 1)
    XCTAssertEqual(handler.processed.first?.id, envelope.id)
  }

  func testFailedDeltaIsRequeuedAndRetried() throws {
    let history = MockHistoryStore()
    let auth = MutableAuth(state: .signedIn(userId: "user", email: nil, displayName: nil))
    let client = IOSConnectivitySyncClient(history: history, auth: auth)
    client.handleAuthState(auth.state)
    let envelope = makeEnvelope()

    var shouldThrow = true
    let retryExpectation = expectation(description: "retry fallback emitted")
    let retryToken = NotificationCenter.default.addObserver(forName: .syncFallbackOccurred, object: nil, queue: .main) { note in
      if note.userInfo?["context"] as? String == "ios.aggregate.delta.retry" {
        retryExpectation.fulfill()
      }
    }
    defer { NotificationCenter.default.removeObserver(retryToken) }

    let processedExpectation = expectation(description: "delta processed twice")
    processedExpectation.expectedFulfillmentCount = 2
    let handler = MockAggregateHandler { _ in
      processedExpectation.fulfill()
      if shouldThrow {
        shouldThrow = false
        throw TestError.expected
      }
    }
    client.setAggregateDeltaHandler(handler)

    client.enqueueAggregateDelta(envelope)

    wait(for: [retryExpectation, processedExpectation], timeout: 1.0)
    XCTAssertEqual(handler.processed.count, 2)
    XCTAssertEqual(handler.processed.first?.id, envelope.id)
    XCTAssertEqual(handler.processed.last?.id, envelope.id)
  }

  func testWCSessionMessageRoundtripQueuesDelta() throws {
#if canImport(WatchConnectivity)
  guard WCSession.isSupported() else {
    throw XCTSkip("WCSession unavailable on this platform")
  }
#endif
    let history = MockHistoryStore()
    let auth = MutableAuth(state: .signedIn(userId: "user", email: nil, displayName: nil))
    let client = IOSConnectivitySyncClient(history: history, auth: auth)
    client.handleAuthState(auth.state)
    let envelope = makeEnvelope()

    let processedExpectation = expectation(description: "delta processed from message")
    let handler = MockAggregateHandler { received in
      XCTAssertEqual(received.id, envelope.id)
      processedExpectation.fulfill()
    }
    client.setAggregateDeltaHandler(handler)

    let encoder = AggregateSyncCoding.makeEncoder()
    let data = try encoder.encode(envelope)
#if canImport(WatchConnectivity)
  client.session(WCSession.default, didReceiveMessage: [
    "type": "aggregateDelta",
    "payload": data
  ])
#endif

    wait(for: [processedExpectation], timeout: 1.0)
  }

  func testWCSessionUserInfoRoundtripQueuesDelta() throws {
#if canImport(WatchConnectivity)
  guard WCSession.isSupported() else {
    throw XCTSkip("WCSession unavailable on this platform")
  }
#endif
    let history = MockHistoryStore()
    let auth = MutableAuth(state: .signedIn(userId: "user", email: nil, displayName: nil))
    let client = IOSConnectivitySyncClient(history: history, auth: auth)
    client.handleAuthState(auth.state)
    let envelope = makeEnvelope()

    let processedExpectation = expectation(description: "delta processed from userInfo")
    let handler = MockAggregateHandler { received in
      XCTAssertEqual(received.id, envelope.id)
      processedExpectation.fulfill()
    }
    client.setAggregateDeltaHandler(handler)

    let encoder = AggregateSyncCoding.makeEncoder()
    let data = try encoder.encode(envelope)
#if canImport(WatchConnectivity)
  client.session(WCSession.default, didReceiveUserInfo: [
    "type": "aggregateDelta",
    "payload": data
  ])
#endif

    wait(for: [processedExpectation], timeout: 1.0)
  }

  private func makeEnvelope() -> AggregateDeltaEnvelope {
    AggregateDeltaEnvelope(
      id: UUID(),
      entity: .team,
      action: .delete,
      payload: nil,
      modifiedAt: Date(),
      origin: .watch
    )
  }
}

@MainActor
private final class MockHistoryStore: MatchHistoryStoring {
  private(set) var saved: [CompletedMatch] = []

  func loadAll() throws -> [CompletedMatch] { saved }
  func save(_ match: CompletedMatch) throws { saved.append(match) }
  func delete(id: UUID) throws { }
  func wipeAll() throws { saved.removeAll() }
}

@MainActor
private final class MutableAuth: AuthenticationProviding {
  private var backingState: AuthState

  init(state: AuthState) {
    self.backingState = state
  }

  var state: AuthState { backingState }

  var currentUserId: String? {
    if case let .signedIn(userId, _, _) = backingState {
      return userId
    }
    return nil
  }

  var currentEmail: String? { nil }
  var currentDisplayName: String? { nil }

  func updateState(_ state: AuthState) {
    backingState = state
  }
}

@MainActor
private final class MockAggregateHandler: AggregateDeltaHandling {
  private let behavior: (AggregateDeltaEnvelope) throws -> Void
  private(set) var processed: [AggregateDeltaEnvelope] = []

  init(_ behavior: @escaping (AggregateDeltaEnvelope) throws -> Void) {
    self.behavior = behavior
  }

  func processDelta(_ envelope: AggregateDeltaEnvelope) async throws {
    processed.append(envelope)
    try behavior(envelope)
  }
}

private enum TestError: Error {
  case expected
}
