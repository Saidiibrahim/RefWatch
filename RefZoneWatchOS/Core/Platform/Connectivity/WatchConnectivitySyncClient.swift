//
//  WatchConnectivitySyncClient.swift
//  RefZoneWatchOS
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
    private let session: WCSessioning?
    private let queue = DispatchQueue(label: "WatchConnectivitySyncClient")
    #endif

    init(session: WCSessioning? = nil) {
        #if canImport(WatchConnectivity)
        self.session = session ?? (WCSession.isSupported() ? WCSessionWrapper.shared : nil)
        self.session?.activate()
        #endif
    }

    var isAvailable: Bool {
        #if canImport(WatchConnectivity)
        #if os(iOS)
        return WCSession.isSupported() && (session?.isPaired ?? false)
        #else
        // On watchOS, `isPaired` is unavailable; availability is effectively WCSession support.
        return WCSession.isSupported()
        #endif
        #else
        return false
        #endif
    }

/// Sends a completed match snapshot to the paired iPhone.
///
/// Envelope
/// - `type: "completedMatch"`
/// - `data: Data` (JSON-encoded CompletedMatch, ISO8601 dates)
///
/// Retry Policy
/// - Encode off the main thread to keep UI responsive.
/// - Prefer `sendMessage` for immediate delivery when reachable; on error, immediately fall back to
///   `transferUserInfo` which is durable and delivered when conditions allow.
/// - In DEBUG builds, posts `.syncFallbackOccurred` on error fallback and `.syncNonrecoverableError` when session/encode fails.
    func sendCompletedMatch(_ match: CompletedMatch) {
        #if canImport(WatchConnectivity)
        guard let session = session else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .syncNonrecoverableError,
                    object: nil,
                    userInfo: ["error": "WCSession unavailable", "context": "watch.sendCompletedMatch.sessionNil"]
                )
            }
            return
        }
        queue.async {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(match) else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .syncNonrecoverableError,
                        object: nil,
                        userInfo: ["error": "encode failed", "context": "watch.sendCompletedMatch.encode"]
                    )
                }
                return
            }
            let payload: [String: Any] = [
                "type": "completedMatch",
                "data": data
            ]

            if session.isReachable {
                session.sendMessage(payload) { error in
                    #if DEBUG
                    print("DEBUG: sendMessage failed: \(error.localizedDescription). Falling back to transferUserInfo.")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .syncFallbackOccurred,
                            object: nil,
                            userInfo: ["context": "watch.sendMessage.errorFallback"]
                        )
                    }
                    #endif
                    session.transferUserInfo(payload)
                }
            } else {
                session.transferUserInfo(payload)
            }
        }
        #else
        // No-op if WatchConnectivity not available
        #endif
    }
}
