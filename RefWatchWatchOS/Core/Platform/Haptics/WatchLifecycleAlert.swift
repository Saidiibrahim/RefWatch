//
//  WatchLifecycleAlert.swift
//  RefWatchWatchOS
//
//  Description: Watch-owned presentation model for repeating lifecycle alerts.
//

import Foundation
import RefWatchCore

/// Describes the modal alert RefWatch shows while a watch-managed lifecycle
/// haptic sequence repeats in the foreground.
struct WatchLifecycleAlert: Equatable, Identifiable, Sendable {
  let id: UUID
  let cue: MatchLifecycleHapticCue
  let title: String
  let message: String

  init(id: UUID = UUID(), cue: MatchLifecycleHapticCue) {
    self.id = id
    self.cue = cue

    switch cue {
    case .periodBoundaryReached:
      self.title = "Time Expired"
      self.message = "Match is paused. Acknowledge to silence this alert. Use Match Actions when you are ready to move on."
    case .halftimeDurationReached:
      self.title = "Half-Time Complete"
      self.message = "Acknowledge to silence this alert. Half-time stays active until you end it from Match Actions."
    }
  }
}
