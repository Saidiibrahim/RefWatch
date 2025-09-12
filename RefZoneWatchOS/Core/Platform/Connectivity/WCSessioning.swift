//
//  WCSessioning.swift
//  RefZoneWatchOS
//
//  Lightweight wrapper over WCSession to enable dependency injection in tests.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

protocol WCSessioning {
    var isReachable: Bool { get }
    func activate()
    func sendMessage(_ message: [String: Any], errorHandler: @escaping (Error) -> Void)
    func transferUserInfo(_ userInfo: [String: Any])
}

final class WCSessionWrapper: WCSessioning {
    static let shared = WCSessionWrapper()
    private let underlying = WCSession.default

    var isReachable: Bool { underlying.isReachable }

    func activate() { underlying.activate() }

    func sendMessage(_ message: [String : Any], errorHandler: @escaping (Error) -> Void) {
        underlying.sendMessage(message, replyHandler: nil, errorHandler: errorHandler)
    }

    func transferUserInfo(_ userInfo: [String : Any]) {
        underlying.transferUserInfo(userInfo)
    }
}
#endif
