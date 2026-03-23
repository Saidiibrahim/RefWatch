import Testing
import RefWatchCore
@testable import RefWatch_Watch_App

@MainActor
struct WatchMatchLifecycleHapticsTests {
  @Test
  func lifecycleCues_scheduleRepeatingNotificationCyclesUntilAcknowledged() async {
    for cue in [MatchLifecycleHapticCue.periodBoundaryReached, .halftimeDurationReached] {
      let scheduler = FakeWatchMatchLifecycleScheduler()
      let driver = FakeWatchMatchLifecycleDriver()
      let haptics = WatchMatchLifecycleHaptics(scheduler: scheduler, driver: driver)

      haptics.play(cue)

      #expect(haptics.activeAlert?.cue == cue)
      #expect(scheduler.scheduledDelays == [0.0, 0.4, 0.8, 3.0])
      scheduler.advance(by: 0.0)
      #expect(driver.playCount == 1)
      scheduler.advance(by: 0.4)
      #expect(driver.playCount == 2)
      scheduler.advance(by: 0.4)
      #expect(driver.playCount == 3)
      scheduler.advance(by: 2.2)
      #expect(scheduler.scheduledDelays == [0.0, 0.4, 0.8, 3.0, 0.0, 0.4, 0.8, 3.0])
      scheduler.advance(by: 0.0)
      #expect(driver.playCount == 4)

      haptics.acknowledgeCurrentAlert()
      scheduler.advance(by: 10.0)
      #expect(driver.playCount == 4)
      #expect(haptics.activeAlert == nil)
    }
  }

  @Test
  func cancelPendingPlayback_suppressesRemainingPulses() async {
    let scheduler = FakeWatchMatchLifecycleScheduler()
    let driver = FakeWatchMatchLifecycleDriver()
    let haptics = WatchMatchLifecycleHaptics(scheduler: scheduler, driver: driver)

    haptics.play(.periodBoundaryReached)
    scheduler.advance(by: 0.0)
    haptics.cancelPendingPlayback()
    scheduler.advance(by: 1.0)

    #expect(driver.playCount == 1)
    #expect(haptics.activeAlert == nil)
  }

  @Test
  func replayingCue_cancelsOldPendingPulsesBeforeSchedulingReplacementSequence() async {
    let scheduler = FakeWatchMatchLifecycleScheduler()
    let driver = FakeWatchMatchLifecycleDriver()
    let haptics = WatchMatchLifecycleHaptics(scheduler: scheduler, driver: driver)

    haptics.play(.periodBoundaryReached)
    scheduler.advance(by: 0.0)
    #expect(driver.playCount == 1)

    haptics.play(.halftimeDurationReached)
    #expect(haptics.activeAlert?.cue == .halftimeDurationReached)
    #expect(scheduler.scheduledDelays == [0.0, 0.4, 0.8, 3.0, 0.0, 0.4, 0.8, 3.0])

    scheduler.advance(by: 0.0)
    #expect(driver.playCount == 2)
    scheduler.advance(by: 0.4)
    #expect(driver.playCount == 3)
    scheduler.advance(by: 0.4)
    #expect(driver.playCount == 4)
    scheduler.advance(by: 1.0)
    #expect(driver.playCount == 4)
  }

  @Test
  func acknowledgeCurrentAlert_clearsAlertAndSuppressesFutureCycles() async {
    let scheduler = FakeWatchMatchLifecycleScheduler()
    let driver = FakeWatchMatchLifecycleDriver()
    let haptics = WatchMatchLifecycleHaptics(scheduler: scheduler, driver: driver)

    haptics.play(.periodBoundaryReached)
    scheduler.advance(by: 0.0)
    scheduler.advance(by: 0.4)
    #expect(driver.playCount == 2)

    haptics.acknowledgeCurrentAlert()
    scheduler.advance(by: 10.0)

    #expect(driver.playCount == 2)
    #expect(haptics.activeAlert == nil)
  }
}

@MainActor
private final class FakeWatchMatchLifecycleScheduler: WatchMatchLifecycleHapticScheduling {
  private struct Entry {
    let id: UUID
    let scheduledAt: TimeInterval
    let action: () -> Void
    var canceled = false
    var executed = false
  }

  private var now: TimeInterval = 0
  private var entries: [UUID: Entry] = [:]
  private(set) var scheduledDelays: [TimeInterval] = []

  func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> any WatchMatchLifecycleScheduledWork {
    let id = UUID()
    self.scheduledDelays.append(delay)
    self.entries[id] = Entry(id: id, scheduledAt: self.now + delay, action: action)
    return FakeScheduledWork { [weak self] in
      self?.entries[id]?.canceled = true
    }
  }

  func advance(by delta: TimeInterval) {
    self.now += delta
    let readyEntries = self.entries.values
      .filter { $0.canceled == false && $0.executed == false && $0.scheduledAt <= self.now }
      .sorted { $0.scheduledAt < $1.scheduledAt }

    for entry in readyEntries {
      self.entries[entry.id]?.executed = true
      entry.action()
    }
  }
}

private struct FakeScheduledWork: WatchMatchLifecycleScheduledWork {
  let onCancel: () -> Void

  func cancel() {
    self.onCancel()
  }
}

private final class FakeWatchMatchLifecycleDriver: WatchMatchLifecycleHapticDriving {
  private(set) var playCount = 0

  func playNotification() {
    self.playCount += 1
  }
}
