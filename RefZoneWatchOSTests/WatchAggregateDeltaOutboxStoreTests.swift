import XCTest
@testable import RefZone_Watch_App
import RefWatchCore
import SwiftData

@MainActor
final class WatchAggregateDeltaOutboxStoreTests: XCTestCase {
  func testMarkAttemptedUpdatesFailureCountAndTimestamp() throws {
    let container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let store = WatchAggregateDeltaOutboxStore(container: container)
    let deltaId = UUID()
    let enqueuedAt = Date(timeIntervalSince1970: 1_000)
    let envelope = makeEnvelope(id: deltaId)

    try store.enqueue(envelope, enqueuedAt: enqueuedAt)

    let attemptDate = Date(timeIntervalSince1970: 2_000)
    try store.markAttempted(ids: [deltaId], at: attemptDate)

    let record = try XCTUnwrap(store.pendingDeltas().first)
    XCTAssertEqual(record.id, deltaId)
    XCTAssertEqual(record.failureCount, 1)
    XCTAssertEqual(record.lastAttemptAt, attemptDate)
    XCTAssertEqual(record.enqueuedAt, enqueuedAt)
  }

  func testPendingDeltasPersistAcrossStoreInitialization() throws {
    let schema = WatchAggregateModelSchema.schema
    let baseDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("watch-aggregate-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let storeURL = baseDirectory.appendingPathComponent("outbox.sqlite")
    let configuration = ModelConfiguration(
      nil,
      schema: schema,
      url: storeURL,
      allowsSave: true,
      cloudKitDatabase: .none
    )

    do {
      let container = try ModelContainer(for: schema, configurations: [configuration])
      let store = WatchAggregateDeltaOutboxStore(container: container)
      try store.enqueue(makeEnvelope(), enqueuedAt: Date(timeIntervalSince1970: 123))
    }

    let reloadContainer = try ModelContainer(for: schema, configurations: [configuration])
    let reloadedStore = WatchAggregateDeltaOutboxStore(container: reloadContainer)
    let pending = try reloadedStore.pendingDeltas()
    XCTAssertEqual(pending.count, 1)
  }

  private func makeEnvelope(id: UUID = UUID()) -> AggregateDeltaEnvelope {
    AggregateDeltaEnvelope(
      id: id,
      entity: .team,
      action: .delete,
      payload: nil,
      modifiedAt: Date(),
      origin: .watch
    )
  }
}
