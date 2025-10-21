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
    private var aggregateSnapshots: [Data] = []
    private var pendingSnapshotChunks: Int = 0
    private var lastSnapshotGeneratedAt: Date?
    private var manualSyncRequestHandler: ((ManualSyncRequestMessage) -> Void)?
    private var lastManualStatus: ManualSyncStatusMessage?
    private var pendingAggregateDeltas: [AggregateDeltaEnvelope] = []
    private var aggregateDeltaHandler: AggregateDeltaHandling?
    private var isProcessingAggregateDeltas = false
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

    func setManualSyncRequestHandler(_ handler: ((ManualSyncRequestMessage) -> Void)?) {
        stateQueue.sync {
            manualSyncRequestHandler = handler
        }
    }

    func setAggregateDeltaHandler(_ handler: AggregateDeltaHandling?) {
        stateQueue.sync {
            aggregateDeltaHandler = handler
        }
        processPendingAggregateDeltas()
    }

    func enqueueAggregateSnapshots(_ snapshots: [AggregateSnapshotPayload]) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let encoder = AggregateSyncCoding.makeEncoder()
        var dataPayloads: [Data] = []
        for snapshot in snapshots {
            do {
                let data = try encoder.encode(snapshot)
                dataPayloads.append(data)
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": "aggregate encode failed",
                        "context": "ios.aggregate.encode"
                    ])
                }
                return
            }
        }

        stateQueue.sync {
            aggregateSnapshots = dataPayloads
            pendingSnapshotChunks = dataPayloads.count
            lastSnapshotGeneratedAt = snapshots.last?.generatedAt
        }

        flushAggregateSnapshots()
        postAggregateStatus()
        #endif
    }

    func reachabilityStatus() -> AggregateSnapshotPayload.Settings.ConnectivityStatus {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return .unknown }
        let session = WCSession.default
        switch session.activationState {
        case .inactive, .notActivated:
            return .unknown
        case .activated:
            return session.isReachable ? .reachable : .unreachable
        @unknown default:
            return .unknown
        }
        #else
        return .unknown
        #endif
    }

    /// Returns real-time snapshot queue status for diagnostics and manual status messages.
    func currentSnapshotQueueStatus() -> (queuedSnapshots: Int, pendingChunks: Int, queuedDeltas: Int) {
        stateQueue.sync {
            (
                queuedSnapshots: aggregateSnapshots.count,
                pendingChunks: pendingSnapshotChunks,
                queuedDeltas: pendingAggregateDeltas.count
            )
        }
    }

    func sendManualSyncStatus(_ status: ManualSyncStatusMessage) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        stateQueue.sync { lastManualStatus = status }
        let encoder = AggregateSyncCoding.makeEncoder()
        guard let data = try? encoder.encode(status) else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                    "error": "manual status encode failed",
                    "context": "ios.aggregate.status.encode"
                ])
            }
            return
        }
        let payload: [String: Any] = [
            "type": status.type,
            "payload": data
        ]
        let session = WCSession.default
        sendWithFallback(payload, context: "ios.aggregate.status.send", session: session)
        #endif
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
                aggregateSnapshots.removeAll()
                pendingSnapshotChunks = 0
                lastSnapshotGeneratedAt = nil
                pendingAggregateDeltas.removeAll()
                return previouslySignedIn
            }
            postAggregateStatus()
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
            processPendingAggregateDeltas()
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

    func enqueueAggregateDelta(_ envelope: AggregateDeltaEnvelope) {
        let state = stateQueue.sync { () -> (Bool, Bool, Bool, Bool) in
            // Check for duplicate using idempotencyKey to prevent double processing
            // when deltas arrive via both sendMessage and transferUserInfo.
            let isDuplicate = pendingAggregateDeltas.contains {
                $0.idempotencyKey == envelope.idempotencyKey
            }
            if isDuplicate {
                AppLog.connectivity.debug("Dropping duplicate aggregate delta idempotencyKey=\(envelope.idempotencyKey.uuidString, privacy: .public)")
                return (false, false, false, true)
            }
            pendingAggregateDeltas.append(envelope)
            return (signedInFlag, aggregateDeltaHandler != nil, isProcessingAggregateDeltas, false)
        }
        let signedIn = state.0
        let handlerAvailable = state.1
        let processing = state.2
        let duplicate = state.3

        if duplicate {
            return
        }

        if handlerAvailable && signedIn && processing == false {
            processPendingAggregateDeltas()
        } else if handlerAvailable == false || signedIn == false {
            NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                "context": "ios.aggregate.delta.queued"
            ])
        }
    }

    func flushAggregateSnapshots() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        // Gate on activation state to prevent "session has not been activated" errors.
        // Snapshots will be retried automatically from activationDidCompleteWith callback.
        guard session.activationState == .activated else {
            AppLog.connectivity.info("Deferring aggregate snapshot flush until WCSession activation completes")
            return
        }

        let snapshots = stateQueue.sync { aggregateSnapshots }
        guard snapshots.isEmpty == false else { return }

        // Send each snapshot using sendMessage with fallback to transferUserInfo on error.
        // This ensures single delivery per snapshot instead of duplicate transmissions.
        for data in snapshots {
            let payload: [String: Any] = [
                "type": "aggregatesSnapshot",
                "payload": data
            ]
            sendWithFallback(payload, context: "ios.aggregate.snapshot.send", session: session)
        }

        // Update application context with the last chunk for background delivery.
        // This provides a lightweight snapshot when the watch wakes up.
        if let last = snapshots.last {
            do {
                try session.updateApplicationContext(["aggregatesSnapshot": last])
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": error.localizedDescription,
                        "context": "ios.aggregate.updateContext"
                    ])
                }
            }
        }

        // Clear bookkeeping after handing off to WCSession.
        // This ensures diagnostics reflect reality instead of permanently showing stale counters.
        stateQueue.sync {
            aggregateSnapshots.removeAll()
            pendingSnapshotChunks = 0
        }
        postAggregateStatus()
        #endif
    }

    func postAggregateStatus() {
        let status = stateQueue.sync { () -> (Int, Date?, Bool, Int, Int) in
            (
                pendingSnapshotChunks,
                lastSnapshotGeneratedAt,
                signedInFlag,
                aggregateSnapshots.count,
                pendingAggregateDeltas.count
            )
        }
        let connectivity = reachabilityStatus()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: [
                "component": "aggregateSync",
                "pendingPushes": status.0,
                "pendingDeletions": 0,
                "signedIn": status.2,
                "timestamp": Date(),
                "pendingSnapshotChunks": status.0,
                "queuedSnapshots": status.3,
                "queuedDeltas": status.4,
                "lastSnapshot": status.1 as Any,
                "connectivityStatus": connectivity.rawValue
            ])
        }
    }

    func handleSendMessageError(_ error: Error, payload: [String: Any], context: String) {
        AppLog.connectivity.error("sendMessage failed (\(context, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
            "context": context
        ])
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            WCSession.default.transferUserInfo(payload)
        }
        #endif
    }

    /// Sends payload using sendMessage with fallback to transferUserInfo only on error.
    /// This ensures single delivery instead of duplicate transmissions.
    func sendWithFallback(
        _ payload: [String: Any],
        context: String,
        session: WCSession
    ) {
        if session.isReachable {
            session.sendMessage(
                payload,
                replyHandler: { _ in
                    // Success - do nothing (no fallback needed)
                },
                errorHandler: { [weak self] error in
                    // Only fallback to durable transfer on ERROR
                    self?.queue.async { [weak self] in
                        self?.handleSendMessageError(error, payload: payload, context: context)
                    }
                }
            )
        } else {
            // Not reachable - skip sendMessage entirely, use durable transfer
            NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                "context": "\(context).unreachable"
            ])
            session.transferUserInfo(payload)
        }
    }

    func processPendingAggregateDeltas() {
        let work = stateQueue.sync { () -> (AggregateDeltaHandling, [AggregateDeltaEnvelope])? in
            guard signedInFlag, let handler = aggregateDeltaHandler, isProcessingAggregateDeltas == false else {
                return nil
            }
            guard pendingAggregateDeltas.isEmpty == false else { return nil }
            isProcessingAggregateDeltas = true
            let envelopes = pendingAggregateDeltas
            pendingAggregateDeltas.removeAll()
            return (handler, envelopes)
        }

        guard let (handler, envelopes) = work else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            var failedEnvelope: AggregateDeltaEnvelope?
            for envelope in envelopes {
                do {
                    try await handler.processDelta(envelope)
                } catch {
                    failedEnvelope = envelope
                    break
                }
            }

            stateQueue.sync {
                if let failed = failedEnvelope {
                    pendingAggregateDeltas.insert(failed, at: 0)
                }
                isProcessingAggregateDeltas = false
            }

            if failedEnvelope != nil {
                NotificationCenter.default.post(name: .syncFallbackOccurred, object: nil, userInfo: [
                    "context": "ios.aggregate.delta.retry"
                ])
            }

            processPendingAggregateDeltas()
        }
    }
}

#if canImport(WatchConnectivity)
extension IOSConnectivitySyncClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        flushAggregateSnapshots()
        postAggregateStatus()
    }

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

        case "syncRequest":
            guard let data = message["payload"] as? Data else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": "missing payload",
                        "context": "ios.didReceiveMessage.syncRequest"
                    ])
                }
                return
            }
            queue.async { [weak self] in
                let decoder = AggregateSyncCoding.makeDecoder()
                guard let request = try? decoder.decode(ManualSyncRequestMessage.self, from: data) else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                            "error": "decode failed",
                            "context": "ios.didReceiveMessage.syncRequest.decode"
                        ])
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.manualSyncRequestHandler?(request)
                }
            }

        case "aggregateDelta":
            guard let data = message["payload"] as? Data else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": "missing payload",
                        "context": "ios.didReceiveMessage.aggregateDelta.payload"
                    ])
                }
                return
            }
            queue.async { [weak self] in
                let decoder = AggregateSyncCoding.makeDecoder()
                guard let envelope = try? decoder.decode(AggregateDeltaEnvelope.self, from: data) else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                            "error": "decode failed",
                            "context": "ios.didReceiveMessage.aggregateDelta.decode"
                        ])
                    }
                    return
                }
                self?.enqueueAggregateDelta(envelope)
            }

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

        case "aggregateDelta":
            guard let data = userInfo["payload"] as? Data else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                        "error": "missing payload",
                        "context": "ios.didReceiveUserInfo.aggregateDelta.payload"
                    ])
                }
                return
            }
            queue.async { [weak self] in
                let decoder = AggregateSyncCoding.makeDecoder()
                guard let envelope = try? decoder.decode(AggregateDeltaEnvelope.self, from: data) else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .syncNonrecoverableError, object: nil, userInfo: [
                            "error": "decode failed",
                            "context": "ios.didReceiveUserInfo.aggregateDelta.decode"
                        ])
                    }
                    return
                }
                self?.enqueueAggregateDelta(envelope)
            }

        default:
            break
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        flushAggregateSnapshots()
        postAggregateStatus()
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
