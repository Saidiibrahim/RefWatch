import Testing
import WatchKit
import RefWatchCore
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
  func willExpireTriggersFallbackRenewal() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    #expect(factory.created.count == 1)

    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()

    // Simulate willExpire — should trigger proactive renewal creating a new session
    firstSession.emitWillExpire()

    #expect(factory.created.count == 2)
  }

  @Test
  func proactiveRenewalChainsWhileInactiveWhenCurrentSessionIsRunning() {
    let factory = FakeRuntimeSessionFactory()
    var isAppActive = true
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { isAppActive },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()

    isAppActive = false
    firstSession.emitWillExpire()

    #expect(factory.created.count == 2)
  }

  @Test
  func oldSessionInvalidationAfterProactiveRenewalIsIgnored() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()
    firstSession.emitWillExpire()

    #expect(factory.created.count == 2)

    controller.extendedRuntimeSession(firstSession, didInvalidateWith: .expired, error: nil)

    #expect(factory.created.count == 2)
  }

  @Test
  func endPreventsFallbackRenewalAfterCleanup() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()
    #expect(controller.hasScheduledRenewalTimerForTesting)

    // end() should clean up; a subsequent willExpire should NOT create a new session
    controller.end(reason: .cancelled)
    #expect(controller.hasScheduledRenewalTimerForTesting == false)
    firstSession.emitWillExpire()

    // After end, cleanup removes the old delegate and currentKind is nil.
    #expect(factory.created.count == 1)
  }

  @Test
  func beginDefersWhileInactiveUntilAppBecomesActive() {
    let factory = FakeRuntimeSessionFactory()
    var isAppActive = false
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { isAppActive },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    #expect(factory.created.isEmpty)

    isAppActive = true
    controller.begin(kind: .match, title: "Match", metadata: [:])

    #expect(factory.created.count == 1)
  }

  @Test
  func proactiveRenewalCreatesNewSessionWhenActive() {
    let factory = FakeRuntimeSessionFactory()
    let controller = BackgroundRuntimeSessionController(
      sessionFactory: { factory.make() },
      isAppActiveProvider: { true },
      maxConsecutiveStartFailures: 3)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    let firstSession = tryRequire(factory.created.first)
    firstSession.emitDidStart()

    // Simulate willExpire (which calls performProactiveRenewal)
    firstSession.emitWillExpire()

    #expect(factory.created.count == 2)

    // The new session should be started
    let secondSession = tryRequire(factory.created.last)
    #expect(secondSession.startCallCount == 1)
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

  @Test
  func alwaysOnTimerUsesHalfTimeElapsedDuringHalfTime() {
    let model = MatchViewModel()
    model.isHalfTime = true
    model.matchTime = "45:00"
    model.halfTimeElapsed = "03:12"

    let content = AlwaysOnTimerView.displayContent(for: model)

    #expect(content.headerText == "HT")
    #expect(content.primaryTime == "03:12")
    #expect(content.secondaryTime == nil)
    #expect(content.accessibilityValue == "03:12")
  }

  @Test
  func alwaysOnTimerUsesMatchTimeWhileWaitingToStartHalfTime() {
    let model = MatchViewModel()
    model.waitingForHalfTimeStart = true
    model.matchTime = "45:00"
    model.halfTimeElapsed = "00:00"

    let content = AlwaysOnTimerView.displayContent(for: model)

    #expect(content.headerText == "HT")
    #expect(content.primaryTime == "45:00")
    #expect(content.secondaryTime == nil)
    #expect(content.accessibilityValue == "45:00")
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

  func emitWillExpire() {
    self.delegate?.extendedRuntimeSessionWillExpire(self)
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
