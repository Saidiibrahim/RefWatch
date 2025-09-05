//
//  IOSConnectivitySyncClient.swift
//  RefWatchiOS
//
//  iOS WatchConnectivity receiver for completed match snapshots.
//

import Foundation
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

extension Notification.Name {
    static let matchHistoryDidChange = Notification.Name("MatchHistoryDidChange")
}

final class IOSConnectivitySyncClient: NSObject {
    private let history: MatchHistoryStoring
    private let auth: AuthenticationProviding

    init(history: MatchHistoryStoring, auth: AuthenticationProviding) {
        self.history = history
        self.auth = auth
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #endif
    }

    // Exposed for tests to bypass WCSession
    func handleCompletedMatch(_ match: CompletedMatch) {
        // Attach ownerId if we have one and the snapshot is missing it
        let snapshot: CompletedMatch
        if match.ownerId == nil, let uid = auth.currentUserId {
            snapshot = CompletedMatch(
                id: match.id,
                completedAt: match.completedAt,
                match: match.match,
                events: match.events,
                schemaVersion: match.schemaVersion,
                ownerId: uid
            )
        } else {
            snapshot = match
        }
        do { try history.save(snapshot) } catch { /* log if needed */ }
        NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
    }
}

#if canImport(WatchConnectivity)
extension IOSConnectivitySyncClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let type = message["type"] as? String, type == "completedMatch" else { return }
        guard let data = message["data"] as? Data else { return }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let match = try? decoder.decode(CompletedMatch.self, from: data) else { return }
        handleCompletedMatch(match)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let type = userInfo["type"] as? String, type == "completedMatch" else { return }
        guard let data = userInfo["data"] as? Data else { return }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let match = try? decoder.decode(CompletedMatch.self, from: data) else { return }
        handleCompletedMatch(match)
    }
}
#endif

