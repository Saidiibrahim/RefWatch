//
//  LiveActivityCommand.swift
//  RefZoneWatchOS
//
//  Discrete commands issued from Widget/App Intent surfaces that the
//  watch app consumes to drive MatchViewModel actions.
//

import Foundation

// MARK: - LiveActivityCommand

enum LiveActivityCommand: String, Codable, CaseIterable {
  case pause
  case resume
  case startHalfTime
  case startSecondHalf
}

// MARK: - LiveActivityCommandEnvelope

struct LiveActivityCommandEnvelope: Codable {
  let id: UUID
  let command: LiveActivityCommand
  let timestamp: Date

  init(id: UUID = UUID(), command: LiveActivityCommand, timestamp: Date = Date()) {
    self.id = id
    self.command = command
    self.timestamp = timestamp
  }
}
