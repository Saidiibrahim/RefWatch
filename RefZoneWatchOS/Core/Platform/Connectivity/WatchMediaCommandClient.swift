//
//  WatchMediaCommandClient.swift
//  RefZoneWatchOS
//
//  Sends lightweight media control commands to the paired iPhone via WatchConnectivity.
//  The iPhone companion translates these commands into MusicKit SystemMusicPlayer actions.
//

import Foundation
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
protocol WorkoutMediaCommandSending: AnyObject {
  var isReady: Bool { get }
  func send(_ command: WorkoutMediaCommand) -> Bool
  func onReachabilityChanged(_ handler: @escaping (Bool) -> Void)
}

@MainActor
final class WatchMediaCommandClient: NSObject, WorkoutMediaCommandSending {
  #if canImport(WatchConnectivity)
  private let session: WCSession?
  private var availabilityHandler: ((Bool) -> Void)?
  #endif

  init(session: WCSession? = WCSession.isSupported() ? WCSession.default : nil) {
    #if canImport(WatchConnectivity)
    self.session = session
    super.init()
    self.session?.delegate = self
    self.session?.activate()
    dispatchAvailability()
    #else
    super.init()
    #endif
  }

  var isReady: Bool {
    #if canImport(WatchConnectivity)
    guard let session else { return false }
    return Self.isSessionAvailable(session)
    #else
    false
    #endif
  }

  func send(_ command: WorkoutMediaCommand) -> Bool {
    #if canImport(WatchConnectivity)
    guard let session = session, Self.isSessionAvailable(session) else { return false }
    let payload: [String: Any] = [
      "type": "mediaCommand",
      "command": command.rawValue
    ]
    if session.isReachable {
      session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
        Task { @MainActor in
          _ = self?.session?.transferUserInfo(payload)
        }
      }
      return true
    } else {
      _ = session.transferUserInfo(payload)
      return true
    }
    #else
    return false
    #endif
  }

  func onReachabilityChanged(_ handler: @escaping (Bool) -> Void) {
    availabilityHandler = handler
    handler(isReady)
  }

  #if canImport(WatchConnectivity)
  private func dispatchAvailability() {
    availabilityHandler?(isReady)
  }

  private static func isSessionAvailable(_ session: WCSession) -> Bool {
    guard session.activationState == .activated else { return false }
    #if os(iOS)
    return session.isPaired && session.isWatchAppInstalled
    #else
    // On watchOS the app can only run when paired, so we just verify the
    // companion installation state.
    return session.isCompanionAppInstalled
    #endif
  }
  #endif
}

#if canImport(WatchConnectivity)
@MainActor
extension WatchMediaCommandClient: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    dispatchAvailability()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    dispatchAvailability()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) { }
  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) { }

  func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
    dispatchAvailability()
  }

}
#endif
