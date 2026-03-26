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
  let message: String?

  init(id: UUID = UUID(), cue: MatchLifecycleHapticCue) {
    self.id = id
    self.cue = cue

    switch cue {
    case let .periodBoundaryReached(boundaryDecision):
      switch boundaryDecision {
      case .firstHalf:
        self.title = "End of Half"
      case .secondHalf:
        self.title = "End of Regulation"
      case .extraTimeFirstHalf:
        self.title = "End of ET 1"
      case .extraTimeSecondHalf:
        self.title = "End of ET 2"
      }
      self.message = nil
    case .halftimeDurationReached:
      self.title = "Half-Time Over"
      self.message = nil
    }
  }
}
