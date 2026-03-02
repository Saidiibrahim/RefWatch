import Testing
import WatchKit
@testable import RefWatch_Watch_App

@MainActor
struct BackgroundRuntimeSessionControllerTests {
  @Test
  func restartOnExpiredInvalidationWhileActivityIsActive() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    #expect(factory.created.count == 1)

    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()
    firstSession.emitInvalidation(reason: .expired)

    #expect(factory.created.count == 2)
  }

  @Test
  func startupFailureRetriesAreCapped() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 2)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    #expect(factory.created.count == 1)

    let firstSession = tryRequire(factory.created.first)
    firstSession.emitInvalidation(reason: .sessionInProgress)

    #expect(factory.created.count == 2)

    let secondSession = tryRequire(factory.created.last)
    secondSession.emitInvalidation(reason: .sessionInProgress)

    // Second startup failure should exhaust retry budget when max is 2.
    #expect(factory.created.count == 2)
  }

  @Test
  func endIsIdempotentAndInvalidatesOnlyOnce() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    let session = tryRequire(factory.created.first)

    controller.end(reason: .cancelled)
    controller.end(reason: .reset)

    #expect(session.invalidateCallCount == 1)

    if case .idle = controller.status {
      #expect(true)
    } else {
      #expect(Bool(false), "Expected controller status to be idle after end")
    }
  }
}

@MainActor
private final class FakeRuntimeSessionFactory {
  private(set) var created: [FakeRuntimeSession] = []

  func make() -> any ExtendedRuntimeSession {
    let session = FakeRuntimeSession()
    self.created.append(session)
    return session
  }
}

@MainActor
private final class FakeRuntimeSession: ExtendedRuntimeSession {
  var delegate: (any ExtendedRuntimeSessionDelegate)?
  private(set) var startCallCount = 0
  private(set) var invalidateCallCount = 0
  var state: WKExtendedRuntimeSessionState = .notStarted

  func start() {
    self.startCallCount += 1
  }

  func invalidate() {
    self.invalidateCallCount += 1
    self.state = .invalid
  }

  func emitDidStart() {
    self.state = .running
    self.delegate?.extendedRuntimeSessionDidStart(self)
  }

  func emitInvalidation(reason: WKExtendedRuntimeSessionInvalidationReason, error: Error? = nil) {
    self.state = .invalid
    self.delegate?.extendedRuntimeSession(self, didInvalidateWith: reason, error: error)
  }
}

@discardableResult
private func tryRequire<T>(_ value: T?, _ message: String = "Expected value to exist") -> T {
  guard let value else {
    Issue.record("\(message)")
    fatalError(message)
  }
  return value
}
