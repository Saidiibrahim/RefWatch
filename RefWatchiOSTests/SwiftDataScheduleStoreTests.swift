import XCTest
import SwiftData
@testable import RefWatchiOS
import RefWatchCore

private struct SignedInAuth: AuthenticationProviding {
  let userId: String

  var state: AuthState { .signedIn(userId: self.userId, email: nil, displayName: nil) }
  var currentUserId: String? { self.userId }
  var currentEmail: String? { nil }
  var currentDisplayName: String? { nil }
}

@MainActor
final class SwiftDataScheduleStoreTests: XCTestCase {
  func testSaveAndLoadPreservesTeamIds() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))

    let homeTeamId = UUID()
    let awayTeamId = UUID()
    try store.save(
      ScheduledMatch(
        homeTeam: "Home",
        awayTeam: "Away",
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        kickoff: Date()))

    let saved = try XCTUnwrap(store.loadAll().first)
    XCTAssertEqual(saved.homeTeamId, homeTeamId)
    XCTAssertEqual(saved.awayTeamId, awayTeamId)
  }

  func testUpsertFromAggregatePreservesTeamIdsInSnapshot() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))
    let homeTeamId = UUID()
    let awayTeamId = UUID()

    _ = try store.upsertFromAggregate(
      AggregateSnapshotPayload.Schedule(
        id: UUID(),
        ownerSupabaseId: "owner",
        lastModifiedAt: Date(),
        remoteUpdatedAt: nil,
        homeName: "Home",
        awayName: "Away",
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        kickoff: Date(),
        competition: "Cup",
        notes: nil,
        statusRaw: "scheduled",
        sourceDeviceId: "device"),
      ownerSupabaseId: "owner")

    let saved = try XCTUnwrap(store.loadAll().first)
    XCTAssertEqual(saved.homeTeamId, homeTeamId)
    XCTAssertEqual(saved.awayTeamId, awayTeamId)
  }

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      ScheduledMatchRecord.self,
      TeamRecord.self,
      PlayerRecord.self,
      TeamOfficialRecord.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
