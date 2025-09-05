//
//  WatchConnectivitySyncClient.swift
//  RefWatch Watch App
//
//  watchOS implementation to export completed matches to the paired iPhone.
//

import Foundation
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class WatchConnectivitySyncClient: ConnectivitySyncProviding {
    #if canImport(WatchConnectivity)
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    #endif

    init() {
        #if canImport(WatchConnectivity)
        if let session = session { session.activate() }
        #endif
    }

    var isAvailable: Bool {
        #if canImport(WatchConnectivity)
        return WCSession.isSupported() && (session?.isPaired ?? false)
        #else
        return false
        #endif
    }

    func sendCompletedMatch(_ match: CompletedMatch) {
        #if canImport(WatchConnectivity)
        guard let session = session else { return }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(match) else { return }

        let payload: [String: Any] = [
            "type": "completedMatch",
            "data": data
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
        #else
        // No-op if WatchConnectivity not available
        #endif
    }
}

