//
//  RefWatchApp.swift
//  RefWatchWatchOS
//
//  Description: Watch app entry point, including active-workout recovery
//  handoff for unfinished Match Mode sessions.
//

import RefWatchCore
import HealthKit
import SwiftData
import SwiftUI
import WatchKit

/// Handles watchOS delegate callbacks that arrive before the SwiftUI scene has
/// recreated its Match Mode runtime controller.
final class RefWatchExtensionDelegate: NSObject, WKApplicationDelegate {
  private let healthStore = HKHealthStore()

  /// Captures any recovered active workout session so Match Mode can reattach
  /// when the app relaunches into an unfinished match.
  func handleActiveWorkoutRecovery() {
    self.healthStore.recoverActiveWorkoutSession { session, error in
      Task { @MainActor in
        guard error == nil, let session else { return }
        MatchWorkoutRecoveryBroker.shared.storeRecoveredSession(session)
      }
    }
  }
}

@main
/// Root watchOS app scene for RefWatch.
struct RefWatch_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor(RefWatchExtensionDelegate.self) private var extensionDelegate
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
        .environmentObject(self.aggregateEnvironment)
    }
  }
}
