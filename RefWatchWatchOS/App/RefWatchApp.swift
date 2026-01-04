//
//  RefWatchApp.swift
//  RefWatchWatchOS
//
//  Created by Ibrahim Saidi on 11/1/2025.
//

import RefWatchCore
import RefWorkoutCore
import SwiftData
import SwiftUI

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
      do {
        container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
      } catch {
        NotificationCenter.default.post(
          name: .syncNonrecoverableError,
          object: nil,
          userInfo: [
            "error": error.localizedDescription,
            "context": "watch.aggregate.container",
          ])
        fatalError("Failed to create in-memory aggregate container: \(error.localizedDescription)")
      }
      NotificationCenter.default.post(
        name: .syncNonrecoverableError,
        object: nil,
        userInfo: [
          "error": "aggregate container fallback to memory",
          "context": "watch.aggregate.container",
        ])
    }
    self.aggregateContainer = container
    let libraryStore = WatchAggregateLibraryStore(container: container)
    self.aggregateLibraryStore = libraryStore
    let chunkStore = WatchAggregateSnapshotChunkStore(container: container)
    self.aggregateChunkStore = chunkStore
    let deltaStore = WatchAggregateDeltaOutboxStore(container: container)
    self.aggregateDeltaStore = deltaStore
    let coordinator = WatchAggregateSyncCoordinator(
      libraryStore: libraryStore,
      chunkStore: chunkStore,
      deltaStore: deltaStore)
    self.aggregateCoordinator = coordinator
    let client = WatchConnectivitySyncClient(aggregateCoordinator: coordinator)
    self.connectivityClient = client
    self.aggregateEnvironment = AggregateSyncEnvironment(
      libraryStore: libraryStore,
      chunkStore: chunkStore,
      deltaStore: deltaStore,
      coordinator: coordinator,
      connectivity: client)
    #else
    fatalError("SwiftData unavailable on watchOS")
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppRootView()
        .environmentObject(self.appModeController)
        .environmentObject(self.aggregateEnvironment)
        .workoutServices(self.workoutServices)
    }
  }
}
