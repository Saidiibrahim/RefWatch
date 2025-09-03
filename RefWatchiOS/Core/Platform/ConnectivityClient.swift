//
//  ConnectivityClient.swift
//  RefWatchiOS
//
//  Very thin WatchConnectivity façade with graceful no-op fallback.
//  For this scaffold it exposes booleans and stubs used by the UI.
//

import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

protocol ConnectivityProviding {
    var isSupported: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    func sendFixtureSummary(home: String, away: String, when: String)
}

final class ConnectivityClient: ConnectivityProviding {
    static let shared = ConnectivityClient()

    #if canImport(WatchConnectivity)
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    #endif

    var isSupported: Bool {
        #if canImport(WatchConnectivity)
        return WCSession.isSupported()
        #else
        return false
        #endif
    }

    var isPaired: Bool {
        #if canImport(WatchConnectivity)
        return session?.isPaired ?? false
        #else
        return false
        #endif
    }

    var isWatchAppInstalled: Bool {
        #if canImport(WatchConnectivity)
        return session?.isWatchAppInstalled ?? false
        #else
        return false
        #endif
    }

    func sendFixtureSummary(home: String, away: String, when: String) {
        #if canImport(WatchConnectivity)
        guard let session = session, session.isReachable else { return }
        let payload: [String: Any] = [
            "type": "fixture",
            "home": home,
            "away": away,
            "when": when
        ]
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        #else
        // No-op in environments without WatchConnectivity.
        #endif
    }
}

