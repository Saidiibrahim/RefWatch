//
//  WCSessioning.swift
//  RefWatchWatchOS
//
//  Lightweight wrapper over WCSession to enable dependency injection in tests.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

protocol WCSessioning: AnyObject {
  var isReachable: Bool { get }
  var delegate: WCSessionDelegate? { get set }
  var receivedApplicationContext: [String: Any] { get }
  func activate()
  func sendMessage(_ message: [String: Any], errorHandler: @escaping (Error) -> Void)
  func transferUserInfo(_ userInfo: [String: Any])
}

final class WCSessionWrapper: WCSessioning {
  static let shared = WCSessionWrapper()
  private let underlying = WCSession.default

  var isReachable: Bool { self.underlying.isReachable }
  var delegate: WCSessionDelegate? {
    get { self.underlying.delegate }
    set { self.underlying.delegate = newValue }
  }

  var receivedApplicationContext: [String: Any] { self.underlying.receivedApplicationContext }

  func activate() { self.underlying.activate() }

  func sendMessage(_ message: [String: Any], errorHandler: @escaping (Error) -> Void) {
    self.underlying.sendMessage(message, replyHandler: nil, errorHandler: errorHandler)
  }

  func transferUserInfo(_ userInfo: [String: Any]) {
    self.underlying.transferUserInfo(userInfo)
  }
}
#endif
