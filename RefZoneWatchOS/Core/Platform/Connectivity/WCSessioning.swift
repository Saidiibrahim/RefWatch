//
//  WCSessioning.swift
//  RefZoneWatchOS
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

    var isReachable: Bool { underlying.isReachable }
    var delegate: WCSessionDelegate? {
        get { underlying.delegate }
        set { underlying.delegate = newValue }
    }
    var receivedApplicationContext: [String: Any] { underlying.receivedApplicationContext }

    func activate() { underlying.activate() }

    func sendMessage(_ message: [String : Any], errorHandler: @escaping (Error) -> Void) {
        underlying.sendMessage(message, replyHandler: nil, errorHandler: errorHandler)
    }

    func transferUserInfo(_ userInfo: [String : Any]) {
        underlying.transferUserInfo(userInfo)
    }
}
#endif
