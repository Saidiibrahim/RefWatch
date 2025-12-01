import Testing
@testable import RefZone_Watch_App

@MainActor
struct LiveActivityCommandHandlerTests {
  @Test
  func test_pauseCommand_invokesPause() async throws {
    let store = MockCommandStore(command: .pause)
    let handler = LiveActivityCommandHandler(store: store)
    let model = MockMatchModel()
    model.isMatchInProgress = true
    model.isPaused = false

    let processed = handler.processPendingCommand(model: model)
    #expect(processed == .pause)
    #expect(model.pauseCallCount == 1)
  }

  @Test
  func test_resumeCommand_invokesResume() async throws {
    let store = MockCommandStore(command: .resume)
    let handler = LiveActivityCommandHandler(store: store)
    let model = MockMatchModel()
    model.isMatchInProgress = true
    model.isPaused = true

    _ = handler.processPendingCommand(model: model)
    #expect(model.resumeCallCount == 1)
  }

  @Test
  func test_halfTimeCommand_invokesStartHalfTime() async throws {
    let store = MockCommandStore(command: .startHalfTime)
    let handler = LiveActivityCommandHandler(store: store)
    let model = MockMatchModel()

    _ = handler.processPendingCommand(model: model)
    #expect(model.startHalfTimeCallCount == 1)
  }

  @Test
  func test_secondHalfCommand_invokesStartSecondHalf() async throws {
    let store = MockCommandStore(command: .startSecondHalf)
    let handler = LiveActivityCommandHandler(store: store)
    let model = MockMatchModel()

    _ = handler.processPendingCommand(model: model)
    #expect(model.startSecondHalfCallCount == 1)
  }
}

// MARK: - Test Doubles

private final class MockCommandStore: LiveActivityCommandStoring {
  private var stored: LiveActivityCommand?

  init(command: LiveActivityCommand?) {
    self.stored = command
  }

  @discardableResult
  func write(_ command: LiveActivityCommand) -> LiveActivityCommandEnvelope {
    stored = command
    return LiveActivityCommandEnvelope(command: command)
  }

  func consume() -> LiveActivityCommandEnvelope? {
    guard let stored else { return nil }
    self.stored = nil
    return LiveActivityCommandEnvelope(command: stored)
  }

  func clear() {
    stored = nil
  }
}

private final class MockMatchModel: MatchCommandHandling {
  var isMatchInProgress: Bool = false
  var isPaused: Bool = false
  var waitingForHalfTimeStart: Bool = false
  var waitingForSecondHalfStart: Bool = false

  private(set) var pauseCallCount = 0
  private(set) var resumeCallCount = 0
  private(set) var startHalfTimeCallCount = 0
  private(set) var startSecondHalfCallCount = 0

  func pauseMatch() {
    pauseCallCount += 1
  }

  func resumeMatch() {
    resumeCallCount += 1
  }

  func startHalfTimeManually() {
    startHalfTimeCallCount += 1
  }

  func startSecondHalfManually() {
    startSecondHalfCallCount += 1
  }
}
