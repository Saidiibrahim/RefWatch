import Foundation
import Observation
import RefWatchCore
import RefWorkoutCore

@Observable
final class WorkoutTimerFaceModel: TimerFaceModel {
  private(set) var matchTime: String = "00:00"
  private(set) var periodTime: String = "00:00"
  private(set) var periodTimeRemaining: String = "--:--"
  private(set) var halfTimeElapsed: String = "00:00"
  private(set) var isInStoppage: Bool = false
  private(set) var formattedStoppageTime: String = "00:00"
  private(set) var isPaused: Bool = false
  private(set) var isHalfTime: Bool = false
  private(set) var waitingForHalfTimeStart: Bool = false
  private(set) var isMatchInProgress: Bool = true
  private(set) var currentPeriod: Int = 1

  private var session: WorkoutSession
  private let onPause: () -> Void
  private let onResume: () -> Void
  private var timer: Timer?

  init(session: WorkoutSession, onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
    self.session = session
    self.onPause = onPause
    self.onResume = onResume
    configureInitialState()
  }

  deinit {
    timer?.invalidate()
  }

  func pauseMatch() {
    guard !isPaused else { return }
    onPause()
    isPaused = true
    timer?.invalidate()
    timer = nil
  }

  func resumeMatch() {
    guard isPaused else { return }
    onResume()
    isPaused = false
    startTimerIfNeeded()
  }

  func startHalfTimeManually() {}
  func beginStoppage() {}
  func endStoppage() {}

  func updateSession(_ session: WorkoutSession) {
    self.session = session
    configureInitialState()
  }

  func updatePauseState(_ paused: Bool) {
    isPaused = paused
    if paused {
      timer?.invalidate()
      timer = nil
    } else {
      startTimerIfNeeded()
    }
  }

  private func configureInitialState() {
    isMatchInProgress = session.state == .active || session.state == .paused
    isPaused = session.state == .paused
    if session.state == .ended || session.state == .aborted {
      timer?.invalidate()
      timer = nil
    } else {
      startTimerIfNeeded()
    }
    refreshStrings(asOf: Date())
  }

  private func startTimerIfNeeded() {
    guard timer == nil else { return }
    guard session.state == .active else { return }
    guard !isPaused else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.refreshStrings(asOf: Date())
    }
  }

  private func refreshStrings(asOf date: Date) {
    let elapsed = session.elapsedDuration(asOf: date)
    matchTime = format(interval: elapsed)
    periodTime = matchTime
    halfTimeElapsed = matchTime

    let plannedDuration = session.segments.compactMap { $0.plannedDuration }.reduce(0, +)
    if plannedDuration > 0 {
      let remaining = max(plannedDuration - elapsed, 0)
      periodTimeRemaining = format(interval: remaining)
      currentPeriod = periodIndex(forElapsed: elapsed, in: plannedDuration) + 1
    } else {
      periodTimeRemaining = "--:--"
      currentPeriod = 1
    }
  }

  private func periodIndex(forElapsed elapsed: TimeInterval, in total: TimeInterval) -> Int {
    guard !session.segments.isEmpty else { return 0 }
    var accumulated: TimeInterval = 0
    for (index, segment) in session.segments.enumerated() {
      let duration = segment.plannedDuration ?? 0
      accumulated += duration
      if elapsed <= accumulated {
        return index
      }
    }
    return max(session.segments.count - 1, 0)
  }

  private func format(interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.minute, .second]
    formatter.zeroFormattingBehavior = [.pad]
    return formatter.string(from: interval) ?? "00:00"
  }
}
