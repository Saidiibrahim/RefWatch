//
//  AggregateSyncEnvironment.swift
//  RefZoneWatchOS
//
//  Shared container exposing aggregate sync dependencies to SwiftUI.
//

import Foundation
import RefWatchCore

@MainActor
final class AggregateSyncEnvironment: ObservableObject {
  let libraryStore: WatchAggregateLibraryStore
  let chunkStore: WatchAggregateSnapshotChunkStore
  let deltaStore: WatchAggregateDeltaOutboxStore
  let coordinator: WatchAggregateSyncCoordinator
  let connectivity: WatchConnectivitySyncClient

  @Published private(set) var status: AggregateSyncStatusRecord
  @Published private(set) var librarySnapshot: MatchLibrarySnapshot

  init(
    libraryStore: WatchAggregateLibraryStore,
    chunkStore: WatchAggregateSnapshotChunkStore,
    deltaStore: WatchAggregateDeltaOutboxStore,
    coordinator: WatchAggregateSyncCoordinator,
    connectivity: WatchConnectivitySyncClient
  ) {
    self.libraryStore = libraryStore
    self.chunkStore = chunkStore
    self.deltaStore = deltaStore
    self.coordinator = coordinator
    self.connectivity = connectivity
    self.status = coordinator.currentStatus()
    self.librarySnapshot = (try? libraryStore.makeMatchLibrarySnapshot()) ?? MatchLibrarySnapshot()

    coordinator.statusDidChange = { [weak self] newStatus in
      self?.status = newStatus
    }
    coordinator.libraryDidChange = { [weak self] in
      guard let self else { return }
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.librarySnapshot = (try? self.libraryStore.makeMatchLibrarySnapshot()) ?? MatchLibrarySnapshot()
      }
    }
  }
}
