import XCTest
@testable import RefZone_Watch_App
import RefWatchCore

final class WatchAggregateSyncCoordinatorTests: XCTestCase {
  @MainActor
  func testDropsStaleSnapshotPayloads() throws {
    let container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let libraryStore = WatchAggregateLibraryStore(container: container)
    let chunkStore = WatchAggregateSnapshotChunkStore(container: container)
    let deltaStore = WatchAggregateDeltaOutboxStore(container: container)
    let coordinator = WatchAggregateSyncCoordinator(
      libraryStore: libraryStore,
      chunkStore: chunkStore,
      deltaStore: deltaStore
    )

    let newDate = Date()
    let staleDate = newDate.addingTimeInterval(-3600)

    let freshPayload = makeSnapshotPayload(
      generatedAt: newDate,
      teamName: "Fresh Team",
      acknowledged: []
    )
    let freshData = try encodePayload(freshPayload)
    coordinator.ingestSnapshotData(freshData)

    var teams = try libraryStore.fetchTeams()
    XCTAssertEqual(teams.count, 1)
    XCTAssertEqual(teams.first?.name, "Fresh Team")

    let stalePayload = makeSnapshotPayload(
      generatedAt: staleDate,
      teamName: "Stale Team",
      acknowledged: [],
      chunkMetadata: AggregateSnapshotPayload.ChunkMetadata(index: 1, count: 2)
    )
    let staleData = try encodePayload(stalePayload)
    coordinator.ingestSnapshotData(staleData)

    teams = try libraryStore.fetchTeams()
    XCTAssertEqual(teams.count, 1)
    XCTAssertEqual(teams.first?.name, "Fresh Team")
    let staleChunks = try chunkStore.chunks(for: staleDate)
    XCTAssertTrue(staleChunks.isEmpty)
  }

  @MainActor
  func testAcknowledgedDeltasPruneOutbox() throws {
    let container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let libraryStore = WatchAggregateLibraryStore(container: container)
    let chunkStore = WatchAggregateSnapshotChunkStore(container: container)
    let deltaStore = WatchAggregateDeltaOutboxStore(container: container)
    let coordinator = WatchAggregateSyncCoordinator(
      libraryStore: libraryStore,
      chunkStore: chunkStore,
      deltaStore: deltaStore
    )

    let deltaId = UUID()
    let envelope = AggregateDeltaEnvelope(
      id: deltaId,
      entity: .team,
      action: .delete,
      payload: nil,
      modifiedAt: Date(),
      origin: .watch
    )
    coordinator.enqueueDeltaEnvelope(envelope)

    var status = coordinator.currentStatus()
    XCTAssertEqual(status.queuedDeltas, 1)

    let payload = makeSnapshotPayload(
      generatedAt: Date(),
      teamName: "Ack Team",
      acknowledged: [deltaId]
    )
    let data = try encodePayload(payload)
    coordinator.ingestSnapshotData(data)

    status = coordinator.currentStatus()
    XCTAssertEqual(status.queuedDeltas, 0)
    let pending = try deltaStore.pendingDeltas()
    XCTAssertTrue(pending.isEmpty)
  }
}

@MainActor
private func makeSnapshotPayload(
  generatedAt: Date,
  teamName: String,
  acknowledged: [UUID],
  chunkMetadata: AggregateSnapshotPayload.ChunkMetadata? = nil
) -> AggregateSnapshotPayload {
  let team = AggregateSnapshotPayload.Team(
    id: UUID(),
    ownerSupabaseId: "owner",
    lastModifiedAt: generatedAt,
    remoteUpdatedAt: nil,
    name: teamName,
    shortName: nil,
    division: nil,
    primaryColorHex: nil,
    secondaryColorHex: nil,
    players: [],
    officials: []
  )

  return AggregateSnapshotPayload(
    schemaVersion: AggregateSyncSchema.currentVersion,
    generatedAt: generatedAt,
    lastSyncedAt: nil,
    acknowledgedChangeIds: acknowledged,
    chunk: chunkMetadata,
    settings: AggregateSnapshotPayload.Settings(connectivityStatus: .reachable),
    teams: [team],
    venues: [],
    competitions: [],
    schedules: []
  )
}

private func encodePayload(_ payload: AggregateSnapshotPayload) throws -> Data {
  let encoder = AggregateSyncCoding.makeEncoder()
  return try encoder.encode(payload)
}
