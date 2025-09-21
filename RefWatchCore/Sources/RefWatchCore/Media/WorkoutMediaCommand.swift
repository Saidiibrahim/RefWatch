//
//  WorkoutMediaCommand.swift
//  RefWatchCore
//
//  Shared identifiers for workout media remote commands.
//

import Foundation

public enum WorkoutMediaCommand: String, Codable {
  case togglePlayPause
  case skipForward
  case skipBackward
}
