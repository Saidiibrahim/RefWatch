import Foundation
import MediaPlayer
import AVFoundation
import Observation
import RefWatchCore

#if canImport(UIKit)
import UIKit
#endif

/// Manages Now Playing metadata locally and proxies transport commands to the paired iPhone.
/// `MPNowPlayingInfoCenter` supplies the metadata, while `WatchConnectivity` delivers play/pause
/// requests for the companion to execute with MusicKit.
@MainActor
@Observable
final class WorkoutSessionMediaViewModel {
  private enum Constants {
    static let artworkSize = CGSize(width: 140, height: 140)
    static let basePollInterval: TimeInterval = 2.5 // Increased from 1.0 for better battery life
    static let fastPollInterval: TimeInterval = 1.0 // Used when media is actively playing
  }

  private(set) var title: String = "Not Playing"
  private(set) var subtitle: String = "Music"
  private(set) var isPlaying: Bool = false
  private(set) var canSkipBackward: Bool = false
  private(set) var canSkipForward: Bool = false
  private(set) var isUsingExternalRoute: Bool = false
  private(set) var routeGlyphName: String = "applewatch"
  private(set) var routeDescription: String = "Playing on Apple Watch"
  private(set) var controlsAvailable: Bool = false

  #if canImport(UIKit)
  private(set) var artworkImage: UIImage?
  #endif

  @ObservationIgnored private let notificationCenter: NotificationCenter
  @ObservationIgnored private let infoCenter = MPNowPlayingInfoCenter.default()
  @ObservationIgnored private var observers: [NSObjectProtocol] = []
  @ObservationIgnored private var pollTimer: Timer?
  @ObservationIgnored private var currentPollInterval: TimeInterval = Constants.basePollInterval
  @ObservationIgnored private let commandClient: WorkoutMediaCommandSending

  init(
    notificationCenter: NotificationCenter = .default,
    commandClient: WorkoutMediaCommandSending? = nil
  ) {
    self.notificationCenter = notificationCenter
    if let commandClient {
      self.commandClient = commandClient
    } else {
      self.commandClient = WatchMediaCommandClient()
    }
  }

  func activate() {
    guard observers.isEmpty else {
      refresh()
      return
    }

    let routeToken = notificationCenter.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.refreshRouteState()
      }
    }

    observers = [routeToken]
    startPolling()
    controlsAvailable = commandClient.isReady
    commandClient.onReachabilityChanged { [weak self] reachable in
      self?.controlsAvailable = reachable
    }
    refresh()
  }

  func deactivate() {
    stopPolling()
    for token in observers {
      notificationCenter.removeObserver(token)
    }
    observers.removeAll()
  }

  func refresh() {
    refreshPlaybackState()
    refreshMetadata()
    refreshRouteState()
  }

  func togglePlayPause() {
    guard controlsAvailable else { return }
    if commandClient.send(.togglePlayPause) {
      refresh()
    } else {
      controlsAvailable = false
    }
  }

  func skipBackward() {
    guard controlsAvailable else { return }
    if commandClient.send(.skipBackward) {
      refresh()
    } else {
      controlsAvailable = false
    }
  }

  func skipForward() {
    guard controlsAvailable else { return }
    if commandClient.send(.skipForward) {
      refresh()
    } else {
      controlsAvailable = false
    }
  }

  // MARK: - Private helpers

  private func startPolling() {
    updatePollInterval()
    pollTimer = Timer.scheduledTimer(withTimeInterval: currentPollInterval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  /// Updates the polling interval based on current playback state
  private func updatePollInterval() {
    // Use faster polling when media is actively playing for better responsiveness
    currentPollInterval = isPlaying ? Constants.fastPollInterval : Constants.basePollInterval
  }

  private func stopPolling() {
    pollTimer?.invalidate()
    pollTimer = nil
  }

  /// Restarts the polling timer with the current interval
  private func restartPollingTimer() {
    stopPolling()
    startPolling()
  }

  private func refreshPlaybackState() {
    let wasPlaying = isPlaying

    switch infoCenter.playbackState {
    case .playing:
      isPlaying = true
    case .paused, .stopped, .interrupted:
      isPlaying = false
    @unknown default:
      isPlaying = false
    }

    let hasInfo = (infoCenter.nowPlayingInfo != nil)
    canSkipBackward = hasInfo
    canSkipForward = hasInfo

    // Update polling interval if playback state changed
    if wasPlaying != isPlaying {
      updatePollInterval()
      restartPollingTimer()
    }
  }

  private func refreshMetadata() {
    guard let info = infoCenter.nowPlayingInfo else {
      title = "Not Playing"
      subtitle = isUsingExternalRoute ? routeDescription : "Music"
  #if canImport(UIKit)
      artworkImage = nil
  #endif
      return
    }

    if let trackTitle = info[MPMediaItemPropertyTitle] as? String, !trackTitle.isEmpty {
      title = trackTitle
    } else {
      title = "Unknown"
    }

    if let artist = info[MPMediaItemPropertyArtist] as? String, !artist.isEmpty {
      subtitle = artist
    } else if let album = info[MPMediaItemPropertyAlbumTitle] as? String, !album.isEmpty {
      subtitle = album
    } else {
      subtitle = routeDescription
    }

  #if canImport(UIKit)
    if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork,
       let image = artwork.image(at: Constants.artworkSize) {
      artworkImage = image
    } else {
      artworkImage = nil
    }
  #endif
  }

  private func refreshRouteState() {
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs

    if let output = outputs.first {
      switch output.portType {
      case .builtInSpeaker, .builtInReceiver:
        isUsingExternalRoute = false
        routeGlyphName = "applewatch"
        routeDescription = "Playing on Apple Watch"
      default:
        isUsingExternalRoute = true
        routeGlyphName = "airplayaudio"
        routeDescription = output.portName
      }
    } else {
      isUsingExternalRoute = false
      routeGlyphName = "applewatch"
      routeDescription = "Playing on Apple Watch"
    }

    if infoCenter.nowPlayingInfo == nil {
      subtitle = isUsingExternalRoute ? routeDescription : "Music"
    }
  }

}
