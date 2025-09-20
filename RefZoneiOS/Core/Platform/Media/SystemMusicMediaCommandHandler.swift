//
//  SystemMusicMediaCommandHandler.swift
//  RefZoneiOS
//
//  Executes workout media commands using the Music app's system player.
//

import Foundation
import MusicKit
import RefWatchCore
internal import os

protocol WorkoutMediaCommandHandling {
  func handle(_ command: WorkoutMediaCommand)
}

final class SystemMusicMediaCommandHandler: WorkoutMediaCommandHandling {
  func handle(_ command: WorkoutMediaCommand) {
    Task {
      guard await ensureAuthorization() else {
        AppLog.connectivity.warning("Music authorization denied; ignoring media command \(command.rawValue)")
        return
      }

      var player = SystemMusicPlayer.shared

      switch command {
      case .togglePlayPause:
        switch player.state.playbackStatus {
        case .playing:
          player.pause()
        default:
          do { try await player.play() } catch {
            AppLog.connectivity.error("Failed to play via SystemMusicPlayer: \(error.localizedDescription, privacy: .public)")
          }
        }

      case .skipForward:
        do { try await player.skipToNextEntry() } catch {
          AppLog.connectivity.error("Failed to skip forward: \(error.localizedDescription, privacy: .public)")
        }

      case .skipBackward:
        do { try await player.skipToPreviousEntry() } catch {
          AppLog.connectivity.error("Failed to skip backward: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }

  private func ensureAuthorization() async -> Bool {
    switch await MusicAuthorization.currentStatus {
    case .authorized:
      return true
    case .notDetermined:
      return await MusicAuthorization.request() == .authorized
    default:
      return false
    }
  }
}
