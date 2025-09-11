//
//  ConnectivitySyncController.swift
//  RefWatchiOS
//
//  Observable controller that owns the WatchConnectivity client and manages
//  its lifecycle across scene phases.
//

import Foundation
import Combine
import RefWatchCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class ConnectivitySyncController: ObservableObject {
    private let client: IOSConnectivitySyncClient

    init(history: MatchHistoryStoring, auth: AuthenticationProviding) {
        self.client = IOSConnectivitySyncClient(history: history, auth: auth)
    }

    func start() {
        client.activate()
    }

    func stop() {
        client.deactivate()
    }

    deinit {
        stop()
    }
}
