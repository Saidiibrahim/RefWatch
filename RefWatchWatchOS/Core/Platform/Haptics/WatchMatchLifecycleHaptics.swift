//
//  WatchMatchLifecycleHaptics.swift
//  RefWatch Watch App
//
//  watchOS implementation of MatchLifecycleHapticsProviding.
//

import Foundation
import Observation
import WatchKit
import RefWatchCore

protocol WatchMatchLifecycleScheduledWork {
  func cancel()
}

protocol WatchMatchLifecycleHapticScheduling {
  @discardableResult
  func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> any WatchMatchLifecycleScheduledWork
}

protocol WatchMatchLifecycleHapticDriving {
  func playNotification()
}

private final class DispatchWorkItemScheduledWork: WatchMatchLifecycleScheduledWork {
  private let workItem: DispatchWorkItem

  init(workItem: DispatchWorkItem) {
    self.workItem = workItem
  }

  func cancel() {
    self.workItem.cancel()
  }
}

private struct DispatchQueueWatchMatchLifecycleScheduler: WatchMatchLifecycleHapticScheduling {
  private let queue: DispatchQueue

  init(queue: DispatchQueue = .main) {
    self.queue = queue
  }

  func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> any WatchMatchLifecycleScheduledWork {
    let workItem = DispatchWorkItem(block: action)
    self.queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    return DispatchWorkItemScheduledWork(workItem: workItem)
  }
}

private struct SystemWatchMatchLifecycleHapticDriver: WatchMatchLifecycleHapticDriving {
  func playNotification() {
    WKInterfaceDevice.current().play(.notification)
  }
}

/// Plays repeated watch haptic sequences for shared match lifecycle cues.
@Observable
final class WatchMatchLifecycleHaptics: MatchLifecycleHapticsProviding {
  private enum Constants {
    static let pulseCount = 3
    static let pulseInterval: TimeInterval = 0.4
    static let cycleInterval: TimeInterval = 3.0
  }

  private(set) var activeAlert: WatchLifecycleAlert?

  @ObservationIgnored
  private let scheduler: any WatchMatchLifecycleHapticScheduling
  @ObservationIgnored
  private let driver: any WatchMatchLifecycleHapticDriving
  @ObservationIgnored
  private var pendingWork: [UUID: any WatchMatchLifecycleScheduledWork] = [:]

  init(
    scheduler: any WatchMatchLifecycleHapticScheduling = DispatchQueueWatchMatchLifecycleScheduler(),
    driver: any WatchMatchLifecycleHapticDriving = SystemWatchMatchLifecycleHapticDriver())
  {
    self.scheduler = scheduler
    self.driver = driver
  }

  func play(_ cue: MatchLifecycleHapticCue) {
    self.performOnMain {
      MatchAlertInvestigationLogger.timestamped(
        "lifecycleHaptics.play cue=\(cue.debugName) existingAlert=\(self.activeAlert?.cue.debugName ?? "none") pendingWork=\(self.pendingWork.count)")
      self.cancelScheduledWork()
      let alert = WatchLifecycleAlert(cue: cue)
      self.activeAlert = alert
      MatchAlertInvestigationLogger.timestamped(
        "lifecycleHaptics.activeAlert set alertID=\(alert.id.uuidString) cue=\(alert.cue.debugName)")
      self.scheduleAlertCycle(for: alert)
    }
  }

  func acknowledgeCurrentAlert() {
    self.performOnMain {
      MatchAlertInvestigationLogger.timestamped(
        "lifecycleHaptics.acknowledge alertID=\(self.activeAlert?.id.uuidString ?? "none") cue=\(self.activeAlert?.cue.debugName ?? "none") pendingWork=\(self.pendingWork.count)")
      self.cancelScheduledWork()
      self.activeAlert = nil
    }
  }

  func cancelPendingPlayback() {
    self.performOnMain {
      MatchAlertInvestigationLogger.timestamped(
        "lifecycleHaptics.cancelPendingPlayback alertID=\(self.activeAlert?.id.uuidString ?? "none") cue=\(self.activeAlert?.cue.debugName ?? "none") pendingWork=\(self.pendingWork.count)")
      self.cancelScheduledWork()
      self.activeAlert = nil
    }
  }

  private func scheduleAlertCycle(for alert: WatchLifecycleAlert) {
    guard self.activeAlert?.id == alert.id else { return }

    MatchAlertInvestigationLogger.timestamped(
      "lifecycleHaptics.scheduleCycle alertID=\(alert.id.uuidString) cue=\(alert.cue.debugName) pulseCount=\(Constants.pulseCount) pulseInterval=\(Constants.pulseInterval) cycleInterval=\(Constants.cycleInterval)")

    for pulseIndex in 0..<Constants.pulseCount {
      let delay = TimeInterval(pulseIndex) * Constants.pulseInterval
      self.schedule(after: delay, for: alert.id) { [weak self] in
        MatchAlertInvestigationLogger.timestamped(
          "lifecycleHaptics.firePulse alertID=\(alert.id.uuidString) cue=\(alert.cue.debugName) pulseIndex=\(pulseIndex)")
        self?.driver.playNotification()
      }
    }

    self.schedule(after: Constants.cycleInterval, for: alert.id) { [weak self] in
      MatchAlertInvestigationLogger.timestamped(
        "lifecycleHaptics.fireCycleRollover alertID=\(alert.id.uuidString) cue=\(alert.cue.debugName)")
      self?.scheduleAlertCycle(for: alert)
    }
  }

  private func schedule(
    after delay: TimeInterval,
    for alertID: UUID,
    action: @escaping () -> Void)
  {
    let workID = UUID()
    let scheduledWork = self.scheduler.schedule(after: delay) { [weak self] in
      guard let self else { return }
      self.performOnMain {
        self.pendingWork.removeValue(forKey: workID)
        guard self.activeAlert?.id == alertID else { return }
        action()
      }
    }
    self.pendingWork[workID] = scheduledWork
  }

  private func cancelScheduledWork() {
    MatchAlertInvestigationLogger.timestamped(
      "lifecycleHaptics.cancelScheduledWork pendingWork=\(self.pendingWork.count)")
    self.pendingWork.values.forEach { $0.cancel() }
    self.pendingWork.removeAll()
  }

  private func performOnMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.sync(execute: work)
    }
  }
}
