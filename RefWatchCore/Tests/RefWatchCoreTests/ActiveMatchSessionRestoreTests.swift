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

  func test_restoreRoundTrip_pendingPeriodBoundaryDecision_preservesBoundaryState_withoutReplayingAlert() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let lifecycleHaptics = MatchLifecycleHapticsSpy()
    let viewModel = MatchViewModel(
      history: MockMatchHistoryService(),
      penaltyManager: PenaltyManager(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      connectivity: nil,
      backgroundRuntimeManager: nil,
      activeMatchSessionStore: store)

    viewModel.currentMatch = Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1)
    viewModel.startMatch()

    let reachedBoundary = await self.waitUntil(timeoutSeconds: 3) {
      viewModel.pendingPeriodBoundaryDecision == .firstHalf
    }
    XCTAssertTrue(reachedBoundary)

    let restoredLifecycleHaptics = MatchLifecycleHapticsSpy()
    let restored = MatchViewModel(
      history: MockMatchHistoryService(),
      penaltyManager: PenaltyManager(),
      haptics: NoopHaptics(),
      lifecycleHaptics: restoredLifecycleHaptics,
      connectivity: nil,
      backgroundRuntimeManager: nil,
      activeMatchSessionStore: store)

    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())
    XCTAssertEqual(restored.pendingPeriodBoundaryDecision, .firstHalf)
    XCTAssertFalse(restored.isMatchInProgress)
    XCTAssertFalse(restored.isPaused)
    XCTAssertFalse(restored.waitingForHalfTimeStart)
    XCTAssertTrue(restored.isInStoppage)
    XCTAssertTrue(restoredLifecycleHaptics.playedCues.isEmpty)
  }

  func test_restoreRoundTrip_preservesFrozenMatchSheets() async throws {
    let store = InMemoryActiveMatchSessionStore()
    let viewModel = self.makeViewModel(store: store)
    viewModel.currentMatch = Match(
      homeTeam: "Home",
      awayTeam: "Away",
      homeMatchSheet: ScheduledMatchSheet(
        sourceTeamName: "Home",
        status: .ready,
        starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 1)],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_400)),
      awayMatchSheet: ScheduledMatchSheet(
        sourceTeamName: "Away",
        status: .draft,
        updatedAt: Date(timeIntervalSince1970: 1_742_000_401)))
    viewModel.startMatch()

    let restored = self.makeViewModel(store: store)
    XCTAssertTrue(restored.restorePersistedActiveMatchSessionIfAvailable())
    XCTAssertEqual(restored.currentMatch?.homeMatchSheet?.starters.first?.displayName, "Starter")
    XCTAssertEqual(restored.currentMatch?.awayMatchSheet?.sourceTeamName, "Away")
    XCTAssertTrue(restored.currentMatch?.hasAnyMatchSheetData == true)
    XCTAssertTrue(restored.currentMatch?.areMatchSheetsReadyForWatch == true)
    XCTAssertFalse(restored.currentMatch?.awayMatchSheet?.hasAnyEntries ?? true)
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

private final class MatchLifecycleHapticsSpy: MatchLifecycleHapticsProviding {
  private(set) var playedCues: [MatchLifecycleHapticCue] = []

  func play(_ cue: MatchLifecycleHapticCue) {
    self.playedCues.append(cue)
  }

  func cancelPendingPlayback() {}
}
