//
//  WatchConnectivitySyncClient.swift
//  RefZoneWatchOS
//
//  Bridges WatchConnectivity traffic for completed matches and aggregate library sync.
//

import Foundation
@preconcurrency import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class WatchConnectivitySyncClient: NSObject, ConnectivitySyncProvidingExtended {
#if canImport(WatchConnectivity)
  private let session: WCSessioning?
  private let queue = DispatchQueue(label: "WatchConnectivitySyncClient")
  private var aggregateCoordinator: WatchAggregateSyncCoordinator? {
    didSet {
      configureAggregateCoordinatorCallbacks(previous: oldValue)
    }
  }
  private let aggregateEncoder = AggregateSyncCoding.makeEncoder()
  private let aggregateDecoder = AggregateSyncCoding.makeDecoder()
  private var lastManualStatus: ManualSyncStatusMessage?
#endif

  init(session: WCSessioning? = nil, aggregateCoordinator: WatchAggregateSyncCoordinator? = nil) {
#if canImport(WatchConnectivity)
    self.session = session ?? (WCSession.isSupported() ? WCSessionWrapper.shared : nil)
    self.aggregateCoordinator = aggregateCoordinator
#endif
    super.init()
#if canImport(WatchConnectivity)
    self.session?.delegate = self
    self.session?.activate()
    configureAggregateCoordinatorCallbacks(previous: nil)
    applyInitialApplicationContext()
    flushAggregateDeltas()
#endif
  }

  func setAggregateCoordinator(_ coordinator: WatchAggregateSyncCoordinator) {
#if canImport(WatchConnectivity)
    aggregateCoordinator = coordinator
    applyInitialApplicationContext()
    flushAggregateDeltas()
#endif
  }

  var isAvailable: Bool {
#if canImport(WatchConnectivity)
    return WCSession.isSupported()
#else
    return false
#endif
  }

  func sendCompletedMatch(_ match: CompletedMatch) {
#if canImport(WatchConnectivity)
    guard let session else {
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
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
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
      let sendOrFallback = {
        // Durable enqueue so we don't lose the match if the phone drops connection mid-send
        session.transferUserInfo(payload)
        NotificationCenter.default.post(
          name: .syncFallbackOccurred,
          object: nil,
          userInfo: ["context": "watch.completedMatch.sendMessageFallback"]
        )
      }

      if session.isReachable {
        session.sendMessage(payload) { _ in
          sendOrFallback()
        }
      } else {
        sendOrFallback()
      }
    }
#endif
  }

  // MARK: - Schedule status update (lightweight)
  /// Sends a lightweight schedule status update to the paired iPhone.
  /// Intended for flipping a scheduled match to in_progress at kickoff.
  func sendScheduleStatusUpdate(scheduledId: UUID, status: String = "in_progress") {
#if canImport(WatchConnectivity)
    guard let session else { return }
    let payload: [String: Any] = [
      "type": "scheduleStatusUpdate",
      "scheduledId": scheduledId.uuidString,
      "status": status
    ]
    if session.isReachable {
      session.sendMessage(payload) { _ in
        Task { @MainActor in
          _ = session.transferUserInfo(payload)
        }
      }
    } else {
      _ = session.transferUserInfo(payload)
    }
#endif
  }

#if canImport(WatchConnectivity)
  func requestManualAggregateSync(reason: ManualSyncRequestMessage.Reason = .manual) {
    guard let session else { return }
    let message = ManualSyncRequestMessage(reason: reason)
    guard let data = try? aggregateEncoder.encode(message) else {
      NotificationCenter.default.post(
        name: .syncNonrecoverableError,
        object: nil,
        userInfo: ["error": "encode failed", "context": "watch.manualSync.encode"]
      )
      return
    }
    let payload: [String: Any] = [
      "type": message.type,
      "payload": data
    ]
    if session.isReachable {
      session.sendMessage(payload) { _ in
        // Only fallback to durable transfer on ERROR
        // (WCSessioning protocol internally provides replyHandler: nil)
        NotificationCenter.default.post(
          name: .syncFallbackOccurred,
          object: nil,
          userInfo: ["context": "watch.manualSync.sendMessageFallback"]
        )
        session.transferUserInfo(payload)
      }
    } else {
      NotificationCenter.default.post(
        name: .syncFallbackOccurred,
        object: nil,
        userInfo: ["context": "watch.manualSync.unreachable"]
      )
      session.transferUserInfo(payload)
    }
  }

  func flushAggregateDeltas() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard let session = self.session, let coordinator = self.aggregateCoordinator else { return }
      let envelopes = coordinator.pendingDeltaEnvelopes()
      guard envelopes.isEmpty == false else { return }
      let encoder = self.aggregateEncoder
      var sent: [UUID] = []
      for envelope in envelopes {
        guard let data = try? encoder.encode(envelope) else {
          NotificationCenter.default.post(
            name: .syncNonrecoverableError,
            object: nil,
            userInfo: ["error": "delta encode failed", "context": "watch.aggregate.encodeDelta"]
          )
          continue
        }
        let payload: [String: Any] = [
          "type": envelope.type,
          "payload": data
        ]
        session.transferUserInfo(payload)
        sent.append(envelope.id)
      }
      if sent.isEmpty == false {
        coordinator.markDeltasAttempted(ids: sent)
      }
    }
  }

  private func configureAggregateCoordinatorCallbacks(previous: WatchAggregateSyncCoordinator?) {
    Task { @MainActor [weak self] in
      previous?.libraryDidChange = nil
      guard let self, let coordinator = self.aggregateCoordinator else { return }
      coordinator.libraryDidChange = { [weak self] in
        self?.flushAggregateDeltas()
      }
    }
  }

  func latestManualStatus() -> ManualSyncStatusMessage? {
    lastManualStatus
  }

  private func applyInitialApplicationContext() {
    guard let session else { return }
    handleApplicationContext(session.receivedApplicationContext)
  }

  private func handleApplicationContext(_ context: [String: Any]) {
    guard
      let data = context["aggregatesSnapshot"] as? Data
    else { return }
    ingestAggregatesSnapshot(data)
  }

  private func handleIncomingMessage(_ message: [String: Any]) {
    if let data = message["aggregatesSnapshot"] as? Data {
      ingestAggregatesSnapshot(data)
      return
    }

    guard let type = message["type"] as? String else { return }
    switch type {
    case "syncStatus":
      guard
        let data = message["payload"] as? Data,
        let status = try? aggregateDecoder.decode(ManualSyncStatusMessage.self, from: data)
      else {
        NotificationCenter.default.post(
          name: .syncNonrecoverableError,
          object: nil,
          userInfo: ["error": "status decode failed", "context": "watch.aggregate.status.decode"]
        )
        return
      }
      lastManualStatus = status
      Task { @MainActor [weak self] in
        self?.aggregateCoordinator?.applyManualSyncStatus(status)
      }
    case "aggregatesSnapshot":
      guard let data = message["payload"] as? Data else {
        NotificationCenter.default.post(
          name: .syncNonrecoverableError,
          object: nil,
          userInfo: ["error": "missing aggregates snapshot payload", "context": "watch.aggregate.snapshot.messagePayload"]
        )
        return
      }
      ingestAggregatesSnapshot(data)
    default:
      break
    }
  }

  private func ingestAggregatesSnapshot(_ data: Data) {
    guard aggregateCoordinator != nil else { return }
    Task { @MainActor [weak self] in
      self?.aggregateCoordinator?.ingestSnapshotData(data)
      self?.flushAggregateDeltas()
    }
  }
#endif
}

#if canImport(WatchConnectivity)
extension WatchConnectivitySyncClient: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    applyInitialApplicationContext()
    flushAggregateDeltas()
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    flushAggregateDeltas()
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    handleApplicationContext(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    handleIncomingMessage(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
    handleIncomingMessage(userInfo)
  }
}
#endif
