import Testing
import RefWatchCore
@testable import RefWatch_Watch_App

@MainActor
struct BackgroundRuntimeSessionControllerTests {
  @Test
  func beginAuthorizesAndStartsSingleWorkoutRuntimeSession() async {
    let provider = FakeMatchRuntimeSessionProvider()
    let controller = BackgroundRuntimeSessionController(provider: provider)

    controller.begin(kind: .match, title: "Match", metadata: ["phase": "in-play"])
    await settleController()

    #expect(provider.authorizationRequestCount == 1)
    #expect(provider.startCount == 1)
    #expect(provider.lastStartedTitle == "Match")
    #expect(provider.lastStartedMetadata["phase"] == "in-play")
    #expect(provider.hasActiveSession)
    #expect(controller.status == .running(startedAt: provider.startedAt ?? Date.distantPast))
  }

  @Test
  func beginUsesRecoveredSessionBeforeStartingNewOne() async {
    let provider = FakeMatchRuntimeSessionProvider()
    provider.recoverResult = true
    let controller = BackgroundRuntimeSessionController(provider: provider)

    controller.begin(kind: .match, title: "Recovered", metadata: ["phase": "halftime"])
    await settleController()

    #expect(provider.recoverCount == 1)
    #expect(provider.startCount == 0)
    #expect(provider.updateCount == 1)
    #expect(controller.status == .running(startedAt: provider.startedAt ?? Date.distantPast))
  }

  @Test
  func endStopsActiveWorkoutSessionOnce() async {
    let provider = FakeMatchRuntimeSessionProvider()
    let controller = BackgroundRuntimeSessionController(provider: provider)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    await settleController()
    controller.end(reason: .completed)
    await settleController()

    #expect(provider.stopReasons == [.completed])
    #expect(provider.hasActiveSession == false)
    #expect(controller.status == .idle)
  }

  @Test
  func deniedAuthorizationFailsWithoutStartingSession() async {
    let provider = FakeMatchRuntimeSessionProvider()
    provider.authorizationResult = false
    let controller = BackgroundRuntimeSessionController(provider: provider)

    controller.begin(kind: .match, title: "Match", metadata: [:])
    await settleController()

    #expect(provider.startCount == 0)
    #expect(controller.status == .failed)
  }

  @Test
  func pauseAndResumeOnlyUpdateRuntimeMetadata() async {
    let provider = FakeMatchRuntimeSessionProvider()
    let controller = BackgroundRuntimeSessionController(provider: provider)

    controller.begin(kind: .match, title: "Match", metadata: ["phase": "in-play", "isPaused": "false"])
    await settleController()

    controller.notifyPause()
    controller.notifyResume()

    #expect(provider.updateCount == 2)
    #expect(provider.lastUpdatedMetadata["isPaused"] == "false")
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

  @Test
  func alwaysOnTimerUsesExpiredHeaderDuringPendingBoundaryDecision() {
    let model = MatchViewModel()
    model.pendingPeriodBoundaryDecision = .firstHalf
    model.matchTime = "45:12"
    model.formattedStoppageTime = "00:12"

    let content = AlwaysOnTimerView.displayContent(for: model)

    #expect(content.headerText == "EXP")
    #expect(content.primaryTime == "45:12")
    #expect(content.secondaryTime == "+00:12")
    #expect(content.accessibilityValue == "45:12, +00:12")
  }
}

@MainActor
private final class FakeMatchRuntimeSessionProvider: MatchRuntimeSessionProviding {
  var hasActiveSession = false
  var startedAt: Date?
  var authorizationResult = true
  var recoverResult = false
  private(set) var recoverCount = 0
  private(set) var authorizationRequestCount = 0
  private(set) var startCount = 0
  private(set) var updateCount = 0
  private(set) var lastStartedTitle: String?
  private(set) var lastStartedMetadata: [String: String] = [:]
  private(set) var lastUpdatedMetadata: [String: String] = [:]
  private(set) var stopReasons: [BackgroundRuntimeEndReason] = []

  func recoverActiveSessionIfPossible() async throws -> Bool {
    self.recoverCount += 1
    if self.recoverResult {
      self.hasActiveSession = true
      self.startedAt = Date(timeIntervalSince1970: 1234)
    }
    return self.recoverResult
  }

  func requestAuthorizationIfNeeded() async throws -> Bool {
    self.authorizationRequestCount += 1
    return self.authorizationResult
  }

  func start(title: String?, metadata: [String : String]) async throws {
    self.startCount += 1
    self.hasActiveSession = true
    self.startedAt = Date(timeIntervalSince1970: 5678)
    self.lastStartedTitle = title
    self.lastStartedMetadata = metadata
  }

  func update(title: String?, metadata: [String : String]) {
    self.updateCount += 1
    self.lastStartedTitle = title
    self.lastUpdatedMetadata = metadata
  }

  func stop(reason: BackgroundRuntimeEndReason) async throws {
    self.stopReasons.append(reason)
    self.hasActiveSession = false
    self.startedAt = nil
  }
}

@MainActor
private func settleController() async {
  for _ in 0..<5 {
    await Task.yield()
  }
}
