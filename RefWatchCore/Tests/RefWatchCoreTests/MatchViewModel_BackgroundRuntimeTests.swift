import XCTest
@testable import RefWatchCore

final class MatchViewModel_BackgroundRuntimeTests: XCTestCase {
  @MainActor
  func test_startMatchBeginsRuntimeSession() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()

    viewModel.startMatch()

    XCTAssertEqual(runtimeSpy.beginCalls.count, 1)
    XCTAssertEqual(runtimeSpy.beginCalls.first?.kind, .match)
    XCTAssertEqual(runtimeSpy.pauseCount, 0)
    XCTAssertEqual(runtimeSpy.resumeCount, 0)
  }

  @MainActor
  func test_pauseAndResumeForwardToRuntimeManager() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()

    viewModel.pauseMatch()
    viewModel.resumeMatch()

    XCTAssertEqual(runtimeSpy.pauseCount, 1)
    XCTAssertEqual(runtimeSpy.resumeCount, 1)
  }

  @MainActor
  func test_finishingMatchEndsRuntimeSession() {
    let runtimeSpy = BackgroundRuntimeManagerSpy()
    let viewModel = MatchViewModel(backgroundRuntime: runtimeSpy)
    viewModel.newMatch.homeTeam = "Home"
    viewModel.newMatch.awayTeam = "Away"
    viewModel.createMatch()
    viewModel.startMatch()

    viewModel.endPenaltiesAndProceed()

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
}

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
}
