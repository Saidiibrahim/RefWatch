//
//  ConnectivitySyncController.swift
//  RefZoneiOS
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
        let mediaHandler = SystemMusicMediaCommandHandler()
        self.client = IOSConnectivitySyncClient(history: history, auth: auth, mediaHandler: mediaHandler)
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
