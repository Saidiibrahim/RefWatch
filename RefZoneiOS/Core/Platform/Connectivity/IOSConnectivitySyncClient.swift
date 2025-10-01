//
//  IOSConnectivitySyncClient.swift
//  RefZoneiOS
//
//  iOS WatchConnectivity receiver for completed match snapshots.
//

import Foundation
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import OSLog

extension Notification.Name {
    static let matchHistoryDidChange = Notification.Name("MatchHistoryDidChange")
}

/// iOS WatchConnectivity receiver for completed match snapshots.
///
/// Envelope
/// - `type: "completedMatch"`
/// - `data: Data` (JSON-encoded CompletedMatch, ISO8601 dates)
///
/// Responsibilities
/// - Activate `WCSession` and listen for `sendMessage` and `transferUserInfo` payloads.
/// - Decode off the main thread; persist and notify on the main actor.
/// - Attach `ownerId` using the provided `AuthenticationProviding` if missing (idempotent).
///
/// Diagnostics (DEBUG only)
/// - Posts `.syncNonrecoverableError` on malformed payloads or decode failures.
/// - `.syncFallbackOccurred` is posted by the watch sender during error fallback.
final class IOSConnectivitySyncClient: NSObject {
    private let history: MatchHistoryStoring
    private let auth: AuthenticationProviding
    private let mediaHandler: WorkoutMediaCommandHandling?
    private let stateQueue = DispatchQueue(label: "IOSConnectivitySyncClient.state")
    private var signedInFlag: Bool = false
    private var pendingMatches: [CompletedMatch] = []
    #if canImport(WatchConnectivity)
    private let queue = DispatchQueue(label: "IOSConnectivitySyncClient.decode")
    #endif

    init(history: MatchHistoryStoring, auth: AuthenticationProviding, mediaHandler: WorkoutMediaCommandHandling? = nil) {
        self.history = history
        self.auth = auth
        self.mediaHandler = mediaHandler
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        guard isSignedIn else {
            AppLog.connectivity.info("Skipping WatchConnectivity activation while signed out")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #endif
    }

    deinit {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            // Ensure delegate does not outlive this object
            if WCSession.default.delegate === self {
                WCSession.default.delegate = nil
            }
        }
        #endif
    }

    // Exposed for tests to bypass WCSession
    func handleCompletedMatch(_ match: CompletedMatch) {
        let shouldQueue = stateQueue.sync { () -> Bool in
            guard signedInFlag else {
                pendingMatches.append(match)
                return true
            }
            return false
        }

        if shouldQueue {
            AppLog.connectivity.notice("Queued completed match from watch while signed out")
            NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                "context": "ios.connectivity.queuedWhileSignedOut"
            ])
            return
        }

        persist(match)
    }

    /// Deactivates the WCSession delegate to avoid dangling references when the app
    /// transitions to background or the controller is torn down.
    func deactivate() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        if WCSession.default.delegate === self {
            WCSession.default.delegate = nil
        }
        #endif
    }

    func handleAuthState(_ state: AuthState) {
        switch state {
        case .signedOut:
            let hadPending = stateQueue.sync { () -> Bool in
                let previouslySignedIn = signedInFlag
                signedInFlag = false
                if previouslySignedIn { pendingMatches.removeAll() }
                return previouslySignedIn
            }
            if hadPending {
                AppLog.connectivity.notice("Discarded queued watch payloads after sign-out")
                NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                    "context": "ios.connectivity.discardedOnSignOut"
                ])
            } else {
                AppLog.connectivity.notice("Watch sync paused: signed-out state")
            }
        case .signedIn:
            let queued = stateQueue.sync { () -> [CompletedMatch] in
                signedInFlag = true
                let matches = pendingMatches
                pendingMatches.removeAll()
                return matches
            }
            guard queued.isEmpty == false else { return }
            AppLog.connectivity.notice("Flushing \(queued.count) queued watch payload(s) after sign-in")
            NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                "context": "ios.connectivity.flushQueued"
            ])
            queued.forEach { persist($0) }
        }
    }
}

private extension IOSConnectivitySyncClient {
    var isSignedIn: Bool {
        stateQueue.sync { signedInFlag }
    }

    func persist(_ match: CompletedMatch) {
        Task { @MainActor in
            let snapshot = match.attachingOwnerIfMissing(using: auth)
            do {
                try history.save(snapshot)
            } catch {
                AppLog.history.error("Failed to save synced snapshot: \(error.localizedDescription, privacy: .public)")
                NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                    "error": "save failed",
                    "context": "ios.connectivity.saveHistory"
                ])
            }
            NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
        }
    }
}

#if canImport(WatchConnectivity)
extension IOSConnectivitySyncClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }

    /// Handles immediate messages. Decodes off the main thread and merges on main.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "completedMatch":
            guard let data = message["data"] as? Data else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: ["error": "missing data", "context": "ios.didReceiveMessage.payload"])
                }
                return
            }
            queue.async { [weak self] in
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                guard let match = try? decoder.decode(CompletedMatch.self, from: data) else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: ["error": "decode failed", "context": "ios.didReceiveMessage.decode"])
                    }
                    return
                }
                self?.handleCompletedMatch(match)
            }

        case "mediaCommand":
            handleMediaCommandPayload(message)

        default:
            break
        }
    }

    /// Handles background transfers. Decodes off the main thread and merges on main.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "completedMatch":
            guard let data = userInfo["data"] as? Data else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: ["error": "missing data", "context": "ios.didReceiveUserInfo.payload"])
                }
                return
            }
            queue.async { [weak self] in
                let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                guard let match = try? decoder.decode(CompletedMatch.self, from: data) else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: ["error": "decode failed", "context": "ios.didReceiveUserInfo.decode"])
                    }
                    return
                }
                self?.handleCompletedMatch(match)
            }

        case "mediaCommand":
            handleMediaCommandPayload(userInfo)

        default:
            break
        }
    }
    private func handleMediaCommandPayload(_ payload: [String: Any]) {
        guard let rawValue = payload["command"] as? String, let command = WorkoutMediaCommand(rawValue: rawValue) else {
            AppLog.connectivity.error("Received malformed media command payload")
            return
        }
        mediaHandler?.handle(command)
    }
}
#endif
