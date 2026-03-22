import XCTest
@testable import RefWatchCore

@MainActor
final class ActiveMatchSessionRestoreTests: XCTestCase {
  func test_restoreRoundTrip_waitingForHalfTimeStart() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let viewModel = self.makeViewModel(store: store)
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.createMatch()
    viewModel.startMatch()
    viewModel.matchTime = "45:00"

    viewModel.endCurrentPeriod()

    let restored = self.makeViewModel(store: store)
    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())

    XCTAssertTrue(restored.waitingForHalfTimeStart)
    XCTAssertFalse(restored.isHalfTime)
    XCTAssertEqual(restored.matchTime, "45:00")
  }

  func test_restoreRoundTrip_waitingForPenaltiesStart() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let viewModel = self.makeViewModel(store: store)
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
    viewModel.createMatch()
    viewModel.startMatch()
    viewModel.endCurrentPeriod()
    viewModel.startHalfTimeManually()
    viewModel.endHalfTimeManually()
    viewModel.startSecondHalfManually()
    viewModel.endCurrentPeriod()
    viewModel.startExtraTimeFirstHalfManually()
    viewModel.endCurrentPeriod()
    viewModel.startExtraTimeSecondHalfManually()
    viewModel.matchTime = "120:00"

    viewModel.endCurrentPeriod()

    let restored = self.makeViewModel(store: store)
    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())

    XCTAssertTrue(restored.waitingForPenaltiesStart)
    XCTAssertEqual(restored.matchTime, "120:00")
  }

  func test_restoreRoundTrip_activePenaltiesPreservesOrderAndUndo() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let viewModel = self.makeViewModel(store: store)
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
    viewModel.createMatch()
    viewModel.waitingForPenaltiesStart = true
    XCTAssertTrue(viewModel.startPenalties(withFirstKicker: .away))
    viewModel.recordPenaltyAttempt(team: .away, result: .scored)
    viewModel.recordPenaltyAttempt(team: .home, result: .missed)

    let restored = self.makeViewModel(store: store)
    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())

    XCTAssertTrue(restored.penaltyShootoutActive)
    XCTAssertEqual(restored.penaltyFirstKicker, .away)
    XCTAssertEqual(restored.nextPenaltyTeam, .away)
    XCTAssertTrue(restored.undoLastPenaltyAttempt())
    XCTAssertEqual(restored.homePenaltiesTaken, 0)
    XCTAssertEqual(restored.awayPenaltiesTaken, 1)
    XCTAssertEqual(restored.nextPenaltyTeam, .home)
  }

  func test_restoreRoundTrip_pausedMatchRehydratesTimerAnchors() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let viewModel = self.makeViewModel(store: store)
    viewModel.configureMatch(duration: 2, periods: 2, halfTimeLength: 1, hasExtraTime: false, hasPenalties: false)
    viewModel.createMatch()
    viewModel.startMatch()
    try await Task.sleep(nanoseconds: 1_100_000_000)
    viewModel.pauseMatch()

    let restored = self.makeViewModel(store: store)
    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(restored.isPaused)
    XCTAssertGreaterThanOrEqual(parseMMSS(restored.matchTime), 1)
    XCTAssertTrue(restored.isInStoppage)
  }

  private func makeViewModel(store: InMemoryActiveMatchSessionStore) -> MatchViewModel {
    MatchViewModel(
      history: MockMatchHistoryService(),
      penaltyManager: PenaltyManager(),
      haptics: NoopHaptics(),
      connectivity: nil,
      backgroundRuntimeManager: nil,
      activeMatchSessionStore: store)
  }
}

@MainActor
private final class InMemoryActiveMatchSessionStore: ActiveMatchSessionStoring {
  private var snapshot: ActiveMatchSessionSnapshot?

  func load() throws -> ActiveMatchSessionSnapshot? {
    self.snapshot
  }

  func save(_ snapshot: ActiveMatchSessionSnapshot) throws {
    self.snapshot = snapshot
  }

  func clear() throws {
    self.snapshot = nil
  }
}

@MainActor
private final class MockMatchHistoryService: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {}
  func delete(id: UUID) throws {}
  func wipeAll() throws {}
}
