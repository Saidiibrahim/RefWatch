//
//  SyncDiagnosticsCenter.swift
//  RefWatchiOS
//
//  Observes sync diagnostics notifications and exposes user-facing state.
//

import Combine
import Foundation
import RefWatchCore

final class SyncDiagnosticsCenter: ObservableObject {
  struct SyncComponentStatus: Equatable {
    var pendingPushes: Int = 0
    var pendingDeletions: Int = 0
    var nextRetry: Date?
    var signedIn: Bool = false
    var lastUpdated: Date = .distantPast
    var pendingSnapshotChunks: Int = 0
    var lastSnapshot: Date?
    var queuedSnapshots: Int = 0
    var queuedDeltas: Int = 0
    var connectivityStatus: AggregateSnapshotPayload.Settings.ConnectivityStatus = .unknown
  }

  enum Component: String {
    case matchHistory = "match_history"
    case teamLibrary = "team_library"
    case schedule
    case journal
    case aggregate = "aggregateSync"
  }

  @Published var lastErrorMessage: String?
  @Published var lastErrorContext: String?
  @Published var showBanner: Bool = false

  @Published private(set) var matchStatus = SyncComponentStatus()
  @Published private(set) var teamStatus = SyncComponentStatus()
  @Published private(set) var scheduleStatus = SyncComponentStatus()
  @Published private(set) var aggregateStatus = SyncComponentStatus()

  private let clock: () -> Date
  private var observerTokens: [NSObjectProtocol] = []
  private var statuses: [Component: SyncComponentStatus] = [:]

  init(center: NotificationCenter = .default, clock: @escaping () -> Date = Date.init) {
    self.clock = clock

    let nonrecoverable = center.addObserver(
      forName: .syncNonrecoverableError,
      object: nil,
      queue: .main)
    { [weak self] note in
      let msg = note.userInfo?["error"] as? String ?? "Sync error"
      let ctx = note.userInfo?["context"] as? String
      self?.lastErrorMessage = msg
      self?.lastErrorContext = ctx
      self?.showBanner = true
    }
    self.observerTokens.append(nonrecoverable)

    let status = center.addObserver(forName: .syncStatusUpdate, object: nil, queue: .main) { [weak self] note in
      guard let componentName = note.userInfo?["component"] as? String,
            let component = Component(rawValue: componentName),
            let self else { return }

      var snapshot = SyncComponentStatus()
      snapshot.pendingPushes = note.userInfo?["pendingPushes"] as? Int ?? 0
      snapshot.pendingDeletions = note.userInfo?["pendingDeletions"] as? Int ?? 0
      snapshot.nextRetry = note.userInfo?["nextRetry"] as? Date
      snapshot.signedIn = note.userInfo?["signedIn"] as? Bool ?? false
      snapshot.lastUpdated = self.clock()
      snapshot.pendingSnapshotChunks = note.userInfo?["pendingSnapshotChunks"] as? Int ?? 0
      snapshot.lastSnapshot = note.userInfo?["lastSnapshot"] as? Date
      snapshot.queuedSnapshots = note.userInfo?["queuedSnapshots"] as? Int ?? 0
      snapshot.queuedDeltas = note.userInfo?["queuedDeltas"] as? Int ?? 0
      if let connectivityRaw = note.userInfo?["connectivityStatus"] as? String,
         let connectivity = AggregateSnapshotPayload.Settings.ConnectivityStatus(rawValue: connectivityRaw)
      {
        snapshot.connectivityStatus = connectivity
      }
      self.apply(status: snapshot, for: component)
    }
    self.observerTokens.append(status)
  }

  deinit {
    for token in observerTokens {
      NotificationCenter.default.removeObserver(token)
    }
    observerTokens.removeAll()
  }

  func dismiss() { self.showBanner = false }
}

extension SyncDiagnosticsCenter {
  private func apply(status: SyncComponentStatus, for component: Component) {
    self.statuses[component] = status
    switch component {
    case .matchHistory:
      self.matchStatus = status
    case .teamLibrary:
      self.teamStatus = status
    case .schedule:
      self.scheduleStatus = status
    case .journal:
      // Journals not yet synced; reserve for future use.
      break
    case .aggregate:
      self.aggregateStatus = status
    }
  }
}
