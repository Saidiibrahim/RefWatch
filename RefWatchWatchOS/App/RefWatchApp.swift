//
//  RefWatchApp.swift
//  RefWatchWatchOS
//
//  Created by Ibrahim Saidi on 11/1/2025.
//

import SwiftUI
import SwiftData
import RefWatchCore
import RefWorkoutCore

@main
struct RefWatch_Watch_AppApp: App {
    @StateObject private var appModeController = AppModeController()
    private let workoutServices = WorkoutServicesFactory.makeDefault()

    private let aggregateContainer: ModelContainer
    private let aggregateLibraryStore: WatchAggregateLibraryStore
    private let aggregateChunkStore: WatchAggregateSnapshotChunkStore
    private let aggregateDeltaStore: WatchAggregateDeltaOutboxStore
    private let aggregateCoordinator: WatchAggregateSyncCoordinator
    private let connectivityClient: WatchConnectivitySyncClient
    private let aggregateEnvironment: AggregateSyncEnvironment

    init() {
#if canImport(SwiftData)
        let container: ModelContainer
        if let persistent = try? WatchAggregateContainerFactory.makeBestEffortContainer() {
            container = persistent
        } else {
            container = try! WatchAggregateContainerFactory.makeContainer(inMemory: true)
            NotificationCenter.default.post(
                name: .syncNonrecoverableError,
                object: nil,
                userInfo: [
                    "error": "aggregate container fallback to memory",
                    "context": "watch.aggregate.container"
                ]
            )
        }
        aggregateContainer = container
        let libraryStore = WatchAggregateLibraryStore(container: container)
        aggregateLibraryStore = libraryStore
        let chunkStore = WatchAggregateSnapshotChunkStore(container: container)
        aggregateChunkStore = chunkStore
        let deltaStore = WatchAggregateDeltaOutboxStore(container: container)
        aggregateDeltaStore = deltaStore
        let coordinator = WatchAggregateSyncCoordinator(
            libraryStore: libraryStore,
            chunkStore: chunkStore,
            deltaStore: deltaStore
        )
        aggregateCoordinator = coordinator
        let client = WatchConnectivitySyncClient(aggregateCoordinator: coordinator)
        connectivityClient = client
        aggregateEnvironment = AggregateSyncEnvironment(
            libraryStore: libraryStore,
            chunkStore: chunkStore,
            deltaStore: deltaStore,
            coordinator: coordinator,
            connectivity: client
        )
#else
        fatalError("SwiftData unavailable on watchOS")
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModeController)
                .environmentObject(aggregateEnvironment)
                .workoutServices(workoutServices)
        }
    }
}
