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
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false

    init(history: MatchHistoryStoring, auth: SupabaseAuthStateProviding) {
        let mediaHandler = SystemMusicMediaCommandHandler()
        self.client = IOSConnectivitySyncClient(history: history, auth: auth, mediaHandler: mediaHandler)

        client.handleAuthState(auth.state)

        auth.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                client.handleAuthState(state)
                if case .signedIn = state, isActive {
                    client.activate()
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        isActive = true
        client.activate()
    }

    func stop() {
        isActive = false
        client.deactivate()
    }

    deinit {
        stop()
    }
}
