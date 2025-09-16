//
//  LiveActivityCommandHandler.swift
//  RefZoneWatchOS
//
//  Bridges persisted LiveActivity commands into MatchViewModel actions.
//

import Foundation
import RefWatchCore

// MARK: - MatchCommandHandling

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

final class LiveActivityCommandHandler {
  private let store: LiveActivityCommandStoring

  init(store: LiveActivityCommandStoring = LiveActivityCommandStore()) {
    self.store = store
  }

  @discardableResult
  func processPendingCommand(model: MatchCommandHandling) -> LiveActivityCommand? {
    guard let envelope = store.consume() else { return nil }

    switch envelope.command {
    case .pause:
      if model.isMatchInProgress && model.isPaused == false {
        model.pauseMatch()
      }
    case .resume:
      if model.isMatchInProgress && model.isPaused {
        model.resumeMatch()
      }
    case .startHalfTime:
      model.startHalfTimeManually()
    case .startSecondHalf:
      model.startSecondHalfManually()
    }

    return envelope.command
  }
}
