//
//  LiveActivityStatePublisher.swift
//  RefZoneWatchOS
//
//  Adaptor that derives LiveActivityState from MatchViewModel on
//  key transitions and persists it for the WidgetKit extension.
//

import Foundation
import WidgetKit
import RefWatchCore

// MARK: - LiveActivityStatePublisher

@MainActor
final class LiveActivityStatePublisher: LiveActivityPublishing {
  private let store: LiveActivityStateStore
  private let reloadKind: String? // Optional specific widget kind

  init(store: LiveActivityStateStore = LiveActivityStateStore(), reloadKind: String? = nil) {
    self.store = store
    self.reloadKind = reloadKind
  }

  func start(state: LiveActivityState) {
    store.write(state)
    reload()
  }

  func update(state: LiveActivityState) {
    store.write(state)
    reload()
  }

  func end() {
    store.clear()
    reload()
  }

  // MARK: - Derivation

  func deriveState(from model: MatchViewModel) -> LiveActivityState? {
    guard let match = model.currentMatch else { return nil }

    // Compute period start as now - elapsed (derived from VM, not recomputed logic)
    let elapsedThisPeriod = Self.parseMMSS(model.periodTime)
    let now = Date()
    let periodStart = now.addingTimeInterval(-elapsedThisPeriod)

    // Expected end while running; use remaining from VM (no recompute)
    let remaining = Self.parseMMSS(model.periodTimeRemaining)
    let expectedEnd: Date? = (model.isMatchInProgress && !model.isPaused && remaining > 0) ? now.addingTimeInterval(remaining) : nil

    let periodLabel = PeriodLabelFormatter.label(for: model)
    let stoppageAccumulated = Self.parseMMSS(model.formattedStoppageTime)
    let elapsedAtPause: TimeInterval? = model.isPaused ? elapsedThisPeriod : nil

    return LiveActivityState(
      version: 1,
      matchIdentifier: match.id.uuidString,
      homeAbbr: model.homeTeamDisplayName,
      awayAbbr: model.awayTeamDisplayName,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      periodLabel: periodLabel,
      isPaused: model.isPaused,
      isInStoppage: model.isInStoppage,
      periodStart: periodStart,
      expectedPeriodEnd: expectedEnd,
      elapsedAtPause: elapsedAtPause,
      stoppageAccumulated: stoppageAccumulated,
      canPause: model.isMatchInProgress && model.isPaused == false,
      canResume: model.isMatchInProgress && model.isPaused,
      canStartHalfTime: model.waitingForHalfTimeStart,
      canStartSecondHalf: model.waitingForSecondHalfStart,
      lastUpdated: now
    )
  }

  // MARK: - Helpers

  func publish(for model: MatchViewModel) {
    guard let state = deriveState(from: model) else {
      end()
      return
    }

    if model.isMatchInProgress || model.isHalfTime || model.penaltyShootoutActive {
      update(state: state)
    } else if model.isFullTime || model.matchCompleted {
      end()
    } else {
      end()
    }
  }

  private func reload() {
    if let kind = reloadKind { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    else { WidgetCenter.shared.reloadAllTimelines() }
  }

  private static func parseMMSS(_ value: String) -> TimeInterval {
    let parts = value.split(separator: ":").map { String($0) }
    guard parts.count == 2, let mm = Int(parts[0]), let ss = Int(parts[1]) else { return 0 }
    return TimeInterval(mm * 60 + ss)
  }
}
