import XCTest
@testable import RefWatch_Watch_App
import RefWatchCore

final class WatchAggregateLibraryStoreMatchLibraryTests: XCTestCase {
  @MainActor
  func testMakeMatchLibrarySnapshotPreservesScheduleTeamIds() throws {
    let container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let store = WatchAggregateLibraryStore(container: container)
    let homeTeamId = UUID()
    let awayTeamId = UUID()

    try store.replaceLibrary(
      with: AggregateSnapshotPayload(
        generatedAt: Date(),
        lastSyncedAt: nil,
        acknowledgedChangeIds: [],
        chunk: nil,
        settings: nil,
        teams: [],
        venues: [],
        competitions: [],
        schedules: [
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
            sourceDeviceId: "device")
        ]))

    let snapshot = try store.makeMatchLibrarySnapshot()
    let schedule = try XCTUnwrap(snapshot.schedules.first)
    XCTAssertEqual(schedule.homeTeamId, homeTeamId)
    XCTAssertEqual(schedule.awayTeamId, awayTeamId)
  }

  @MainActor
  func testMakeMatchLibrarySnapshotPreservesScheduleMatchSheets() throws {
    let container = try WatchAggregateContainerFactory.makeContainer(inMemory: true)
    let store = WatchAggregateLibraryStore(container: container)
    let homeSheet = ScheduledMatchSheet(
      sourceTeamName: "Home",
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 1)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_700))
    let awaySheet = ScheduledMatchSheet(
      sourceTeamName: "Away",
      status: .draft,
      starters: [],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_701))

    try store.replaceLibrary(
      with: AggregateSnapshotPayload(
        generatedAt: Date(),
        lastSyncedAt: nil,
        acknowledgedChangeIds: [],
        chunk: nil,
        settings: nil,
        teams: [],
        venues: [],
        competitions: [],
        schedules: [
          AggregateSnapshotPayload.Schedule(
            id: UUID(),
            ownerSupabaseId: "owner",
            lastModifiedAt: Date(),
            remoteUpdatedAt: nil,
            homeName: "Home",
            awayName: "Away",
            homeMatchSheet: homeSheet,
            awayMatchSheet: awaySheet,
            kickoff: Date(),
            competition: "Cup",
            notes: nil,
            statusRaw: "scheduled",
            sourceDeviceId: "device")
        ]))

    let snapshot = try store.makeMatchLibrarySnapshot()
    let schedule = try XCTUnwrap(snapshot.schedules.first)
    XCTAssertEqual(schedule.homeMatchSheet, homeSheet.normalized())
    XCTAssertEqual(schedule.awayMatchSheet, awaySheet.normalized())
  }
}
