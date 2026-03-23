import Foundation
import Testing
import RefWatchCore
@testable import RefWatch_Watch_App

@MainActor
struct PersistedActiveMatchSessionStoreTests {
  @Test
  func restorePersistedSession_whenHalftimeCueWasAlreadyRequested_doesNotReplayCue() throws {
    let suiteName = "RefWatch.WatchTests.\(UUID().uuidString)"
    let store = PersistedActiveMatchSessionStore(suiteName: suiteName)
    defer {
      try? store.clear()
      UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    let snapshot = ActiveMatchSessionSnapshot(
      match: Match(duration: 2, numberOfPeriods: 2, halfTimeLength: 1),
      currentPeriod: 1,
      isMatchInProgress: false,
      isHalfTime: true,
      isPaused: false,
      waitingForMatchStart: false,
      waitingForHalfTimeStart: false,
      waitingForSecondHalfStart: false,
      waitingForET1Start: false,
      waitingForET2Start: false,
      waitingForPenaltiesStart: false,
      isFullTime: false,
      matchCompleted: false,
      displayState: ActiveMatchDisplayState(
        matchTime: "45:00",
        periodTime: "45:00",
        periodTimeRemaining: "00:00",
        halfTimeRemaining: "00:00",
        halfTimeElapsed: "00:02",
        formattedStoppageTime: "00:00"),
      isInStoppage: false,
      homeTeamKickingOff: true,
      homeTeamKickingOffET1: nil,
      matchEvents: [],
      penaltyState: PenaltyShootoutSnapshot(),
      timerState: TimerManager.PersistenceState(
        halfTimeStartTime: Date().addingTimeInterval(-2),
        didRequestHalftimeDurationCue: true),
      penaltyStartEventLogged: false)

    try store.save(snapshot)
    #expect(try store.load()?.timerState.didRequestHalftimeDurationCue == true)

    let lifecycleHaptics = MatchLifecycleHapticsSpy()
    let restored = MatchViewModel(
      history: InMemoryHistoryStore(),
      penaltyManager: PenaltyManager(),
      haptics: NoopHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      connectivity: nil,
      backgroundRuntimeManager: nil,
      activeMatchSessionStore: store)

    #expect(restored.restorePersistedActiveMatchSessionIfAvailable())
    #expect(restored.isHalfTime)
    #expect(lifecycleHaptics.playedCues.isEmpty)
  }
}

private final class MatchLifecycleHapticsSpy: MatchLifecycleHapticsProviding {
  private(set) var playedCues: [MatchLifecycleHapticCue] = []

  func play(_ cue: MatchLifecycleHapticCue) {
    self.playedCues.append(cue)
  }

  func cancelPendingPlayback() {}
}
