import XCTest
@testable import RefWatchCore

final class MatchViewModel_BackgroundRuntimeTests: XCTestCase {
  @MainActor
  func test_createMatchBeginsRuntimeSessionWhileWaitingForKickoff() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"

    viewModel.createMatch()

    XCTAssertEqual(runtimeSpy.beginCalls.count, 1)
    XCTAssertEqual(runtimeSpy.beginCalls.first?.kind, .match)
    XCTAssertEqual(runtimeSpy.beginCalls.first?.metadata["phase"], "waiting-kickoff")
    XCTAssertEqual(runtimeSpy.pauseCount, 0)
    XCTAssertEqual(runtimeSpy.resumeCount, 1)
  }

  @MainActor
  func test_startMatchBeginsRuntimeSession() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    runtimeSpy.resetHistory()

    viewModel.startMatch()

    XCTAssertEqual(runtimeSpy.beginCalls.count, 1)
    XCTAssertEqual(runtimeSpy.beginCalls.first?.kind, .match)
    XCTAssertEqual(runtimeSpy.beginCalls.first?.metadata["phase"], "in-play")
    XCTAssertEqual(runtimeSpy.pauseCount, 0)
    XCTAssertEqual(runtimeSpy.resumeCount, 1)
  }

  @MainActor
  func test_pauseAndResumeForwardToRuntimeManager() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    runtimeSpy.resetHistory()
    viewModel.startMatch()

    viewModel.pauseMatch()
    viewModel.resumeMatch()

    XCTAssertEqual(runtimeSpy.pauseCount, 1)
    XCTAssertEqual(runtimeSpy.resumeCount, 2)
  }

  @MainActor
  func test_runtimeStaysActiveUntilFinalCompletion() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()
    runtimeSpy.resetHistory()

    viewModel.endPenaltiesAndProceed()
    XCTAssertTrue(viewModel.isFullTime)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)

    viewModel.finalizeMatch()

    XCTAssertEqual(runtimeSpy.endReasons.last, .completed)
  }

  @MainActor
  func test_resetMatchEndsRuntimeSession() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()

    viewModel.resetMatch()

    XCTAssertEqual(runtimeSpy.endReasons.last, .reset)
  }

  @MainActor
  func test_runtimeStaysActiveAcrossHalfTimeAndSecondHalfWaitingState() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.startMatch()

    viewModel.endCurrentPeriod()
    XCTAssertTrue(viewModel.waitingForHalfTimeStart)
    XCTAssertFalse(viewModel.isHalfTime)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["phase"], "waiting-halftime")

    viewModel.startHalfTimeManually()
    viewModel.endHalfTimeManually()
    XCTAssertTrue(viewModel.waitingForSecondHalfStart)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["phase"], "waiting-second-half")
  }

  @MainActor
  func test_natural_period_expiry_updates_runtime_to_pending_boundary_phase() async {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.currentMatch = Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1)
    viewModel.startMatch()

    let reachedBoundary = await self.waitUntil(timeoutSeconds: 3) {
      viewModel.pendingPeriodBoundaryDecision == .firstHalf
    }

    XCTAssertTrue(reachedBoundary)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["phase"], "pending-period-end-first-half")
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["isPaused"], "false")
  }

  @MainActor
  func test_runtimeStaysActiveAcrossExtraTimeAndPenaltiesTransitions() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
    viewModel.startMatch()

    viewModel.endCurrentPeriod()
    viewModel.startHalfTimeManually()
    viewModel.endHalfTimeManually()
    viewModel.startSecondHalfManually()
    viewModel.endCurrentPeriod()
    XCTAssertTrue(viewModel.waitingForET1Start)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)

    viewModel.startExtraTimeFirstHalfManually()
    viewModel.endCurrentPeriod()
    XCTAssertTrue(viewModel.waitingForET2Start)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)

    viewModel.startExtraTimeSecondHalfManually()
    viewModel.endCurrentPeriod()
    XCTAssertTrue(viewModel.waitingForPenaltiesStart)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)

    viewModel.beginPenaltiesIfNeeded()
    XCTAssertTrue(viewModel.penaltyShootoutActive)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["phase"], "penalties")
  }

  @MainActor
  func test_reconcileCalledOnInactiveScenePhaseKeepsSessionAlive() {
    // Verifies that reconcile during .inactive refreshes runtime protection
    // without ending the session when a match is in progress.
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()
    runtimeSpy.resetHistory()

    // Simulate what .inactive scene phase handler does
    viewModel.reconcileBackgroundRuntimeSession()

    XCTAssertEqual(runtimeSpy.beginCalls.count, 1)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
  }

  @MainActor
  func test_reconcileEndsRuntimeWhenNoProtectedStateIsActive() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()

    viewModel.isMatchInProgress = false
    viewModel.isPaused = false
    viewModel.isHalfTime = false
    viewModel.waitingForHalfTimeStart = false
    viewModel.waitingForSecondHalfStart = false
    viewModel.waitingForET1Start = false
    viewModel.waitingForET2Start = false
    viewModel.waitingForPenaltiesStart = false
    viewModel.isFullTime = false

    viewModel.reconcileBackgroundRuntimeSession()

    XCTAssertEqual(runtimeSpy.endReasons.last, .cancelled)
  }

  @MainActor
  func test_fullTimeBeforeFinalizeRemainsRuntimeProtected() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()
    runtimeSpy.resetHistory()

    viewModel.endPenaltiesAndProceed()

    XCTAssertTrue(viewModel.isFullTime)
    XCTAssertTrue(runtimeSpy.endReasons.isEmpty)
    XCTAssertEqual(runtimeSpy.beginCalls.last?.metadata["phase"], "full-time-pending-completion")
  }
}

private extension MatchViewModel_BackgroundRuntimeTests {
  @MainActor
  func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () -> Bool) async -> Bool {
    let timeoutNanos = UInt64(timeoutSeconds * 1_000_000_000)
    let stepNanos: UInt64 = 100_000_000
    var elapsedNanos: UInt64 = 0

    while elapsedNanos < timeoutNanos {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: stepNanos)
      elapsedNanos += stepNanos
    }

    return condition()
  }
}

@MainActor
private final class BackgroundRuntimeManagerSpy: BackgroundRuntimeManaging, @unchecked Sendable {
  struct BeginCall {
    let kind: BackgroundRuntimeActivityKind
    let title: String?
    let metadata: [String: String]
  }

  private(set) var beginCalls: [BeginCall] = []
  private(set) var pauseCount = 0
  private(set) var resumeCount = 0
  private(set) var endReasons: [BackgroundRuntimeEndReason] = []

  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {
    beginCalls.append(BeginCall(kind: kind, title: title, metadata: metadata))
  }

  func notifyPause() {
    pauseCount += 1
  }

  func notifyResume() {
    resumeCount += 1
  }

  func end(reason: BackgroundRuntimeEndReason) {
    endReasons.append(reason)
  }

  func resetHistory() {
    beginCalls.removeAll()
    pauseCount = 0
    resumeCount = 0
    endReasons.removeAll()
  }
}
