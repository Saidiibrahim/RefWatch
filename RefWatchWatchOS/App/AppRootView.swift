import RefWatchCore
import SwiftUI

struct AppRootView: View {
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment

  var body: some View {
    MatchRootView(connectivity: self.aggregateEnvironment.connectivity)
  }
}

#Preview("Match Mode") {
  let environment = makePreviewAggregateEnvironment()

  return AppRootView()
    .environmentObject(environment)
}

@MainActor
private func makePreviewAggregateEnvironment() -> AggregateSyncEnvironment {
  guard let container = try? WatchAggregateContainerFactory.makeContainer(inMemory: true) else {
    fatalError("Failed to create preview aggregate container")
  }
  let library = WatchAggregateLibraryStore(container: container)
  let chunk = WatchAggregateSnapshotChunkStore(container: container)
  let delta = WatchAggregateDeltaOutboxStore(container: container)
  let coordinator = WatchAggregateSyncCoordinator(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta)
  let connectivity = WatchConnectivitySyncClient(session: nil, aggregateCoordinator: coordinator)
  return AggregateSyncEnvironment(
    libraryStore: library,
    chunkStore: chunk,
    deltaStore: delta,
    coordinator: coordinator,
    connectivity: connectivity)
}
