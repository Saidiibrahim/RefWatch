//
//  PendingPeriodBoundaryDecision.swift
//  RefWatchCore
//
//  Description: Shared lifecycle state used when a natural period boundary has
//  expired but the referee has not yet explicitly committed the period end.
//

import Foundation

public enum PendingPeriodBoundaryDecision: String, Codable, Equatable, Sendable {
  case firstHalf
  case secondHalf
  case extraTimeFirstHalf
  case extraTimeSecondHalf
}
