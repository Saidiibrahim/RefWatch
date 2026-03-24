//
//  PeriodLabelFormatter.swift
//  RefWatchWatchOS
//
//  Centralizes human-readable period label derivation for consistency
//  across TimerView and LiveActivity state publishing.
//

import Foundation
import RefWatchCore

struct PeriodLabelFormatter {
  @MainActor
  static func label(for model: MatchViewModel) -> String {
    if let pendingPeriodBoundaryDecision = model.pendingPeriodBoundaryDecision {
      switch pendingPeriodBoundaryDecision {
      case .firstHalf:
        return "1st Half Expired"
      case .secondHalf:
        return (model.currentMatch?.hasExtraTime ?? false) ? "2nd Half Expired" : "Match Time Expired"
      case .extraTimeFirstHalf:
        return "ET 1 Expired"
      case .extraTimeSecondHalf:
        return "ET 2 Expired"
      }
    }
    if model.isHalfTime && !model.waitingForHalfTimeStart { return "Half Time" }
    if model.waitingForHalfTimeStart { return "Half Time" }
    if model.waitingForSecondHalfStart { return "Second Half" }

    switch model.currentPeriod {
    case 1: return "First Half"
    case 2: return "Second Half"
    case 3: return "ET 1"
    case 4: return "ET 2"
    default:
      if model.penaltyShootoutActive || model.waitingForPenaltiesStart { return "Penalties" }
      return "Full Time"
    }
  }
}
