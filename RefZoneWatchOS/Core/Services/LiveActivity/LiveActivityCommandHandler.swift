//
//  LiveActivityCommandHandler.swift
//  RefZoneWatchOS
//
//  Bridges persisted LiveActivity commands into MatchViewModel actions.
//

import Foundation
import RefWatchCore

// MARK: - MatchCommandHandling

@MainActor
protocol MatchCommandHandling {
  var isMatchInProgress: Bool { get }
  var isPaused: Bool { get }
  var waitingForHalfTimeStart: Bool { get }
  var waitingForSecondHalfStart: Bool { get }

  func pauseMatch()
  func resumeMatch()
  func startHalfTimeManually()
  func startSecondHalfManually()
}

extension MatchViewModel: MatchCommandHandling {}

// MARK: - LiveActivityCommandHandling

@MainActor
final class LiveActivityCommandHandler {
  private let store: LiveActivityCommandStoring

  init(store: LiveActivityCommandStoring = LiveActivityCommandStore()) {
    self.store = store
  }

  /// Consumes the most recent widget-issued command and forwards it to the
  /// provided model when the transition is valid. Returns `nil` when no action
  /// was performed so the caller can skip redundant UI updates.
  @discardableResult
  func processPendingCommand(model: MatchCommandHandling) -> LiveActivityCommand? {
    guard let envelope = store.consume() else { return nil }

    var didHandle = false

    switch envelope.command {
    case .pause:
      if model.isMatchInProgress && model.isPaused == false {
        model.pauseMatch()
        didHandle = true
      }
    case .resume:
      if model.isMatchInProgress && model.isPaused {
        model.resumeMatch()
        didHandle = true
      }
    case .startHalfTime:
      if model.waitingForHalfTimeStart {
        model.startHalfTimeManually()
        didHandle = true
      }
    case .startSecondHalf:
      if model.waitingForSecondHalfStart {
        model.startSecondHalfManually()
        didHandle = true
      }
    }

    return didHandle ? envelope.command : nil
  }
}
