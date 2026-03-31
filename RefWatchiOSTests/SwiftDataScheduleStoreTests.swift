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

  func testUpcomingMatchEditorSavePayloadPreservesExistingTeamIdsAndImportedProvenance() {
    let preservedHomeTeamId = UUID()
    let preservedAwayTeamId = UUID()
    let preservedSourceTeamId = UUID()
    let kickoff = Date(timeIntervalSince1970: 1_742_000_900)
    let savedAt = Date(timeIntervalSince1970: 1_742_000_901)
    let existingMatch = ScheduledMatch(
      id: UUID(),
      homeTeam: "Original Home",
      awayTeam: "Original Away",
      homeTeamId: preservedHomeTeamId,
      awayTeamId: preservedAwayTeamId,
      homeMatchSheet: MatchSheetDraftFactory.emptyDraft(teamName: "Original Home"),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(teamName: "Original Away"),
      kickoff: kickoff)

    let item = UpcomingMatchEditorView.scheduledMatchForSave(
      existingMatch: existingMatch,
      homeName: "Metro FC",
      awayName: "Rivals FC",
      kickoff: kickoff,
      homeMatchSheet: ScheduledMatchSheet(
        sourceTeamId: preservedSourceTeamId,
        sourceTeamName: "Imported Metro",
        status: .draft,
        starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 3)],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_800)),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(teamName: "Rivals FC"),
      now: savedAt)

    XCTAssertEqual(item.homeTeamId, preservedHomeTeamId)
    XCTAssertEqual(item.awayTeamId, preservedAwayTeamId)
    XCTAssertEqual(item.homeMatchSheet?.sourceTeamId, preservedSourceTeamId)
    XCTAssertEqual(item.homeMatchSheet?.sourceTeamName, "Imported Metro")
    XCTAssertEqual(item.lastModifiedAt, savedAt)
  }

  func testUpcomingMatchEditorSavePayloadDoesNotMintTeamIdsForNewMatches() {
    let kickoff = Date(timeIntervalSince1970: 1_742_000_902)
    let item = UpcomingMatchEditorView.scheduledMatchForSave(
      existingMatch: nil,
      homeName: "Metro FC",
      awayName: "Rivals FC",
      kickoff: kickoff,
      homeMatchSheet: MatchSheetDraftFactory.emptyDraft(teamName: "Metro FC"),
      awayMatchSheet: MatchSheetDraftFactory.emptyDraft(teamName: "Rivals FC"),
      now: Date(timeIntervalSince1970: 1_742_000_903))

    XCTAssertNil(item.homeTeamId)
    XCTAssertNil(item.awayTeamId)
    XCTAssertNil(item.homeMatchSheet?.sourceTeamId)
    XCTAssertNil(item.awayMatchSheet?.sourceTeamId)
    XCTAssertEqual(item.homeMatchSheet?.sourceTeamName, "Metro FC")
    XCTAssertEqual(item.awayMatchSheet?.sourceTeamName, "Rivals FC")
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

  func testSaveAndLoadPreservesMatchSheets() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))
    let homeSheet = ScheduledMatchSheet(
      sourceTeamName: "Home",
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 1)],
      substitutes: [MatchSheetPlayerEntry(displayName: "Bench", shirtNumber: 14, sortOrder: 2)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_600))
    let awaySheet = ScheduledMatchSheet(
      sourceTeamName: "Away",
      status: .draft,
      starters: [],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_601))

    try store.save(
      ScheduledMatch(
        homeTeam: "Home",
        awayTeam: "Away",
        homeMatchSheet: homeSheet,
        awayMatchSheet: awaySheet,
        kickoff: Date()))

    let saved = try XCTUnwrap(store.loadAll().first)
    XCTAssertEqual(saved.homeMatchSheet, homeSheet.normalized())
    XCTAssertEqual(saved.awayMatchSheet, awaySheet.normalized())
  }

  func testSaveAndLoadPreservesAuthoredAdHocOrderAcrossRoundTrip() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))
    let homeSheet = MatchSheetEditorState.normalizedSheet(
      ScheduledMatchSheet(
        sourceTeamName: "Home",
        status: .draft,
        starters: [
          MatchSheetPlayerEntry(displayName: "Late Add", shirtNumber: nil, sortOrder: Int.max),
          MatchSheetPlayerEntry(displayName: "Captain", shirtNumber: 4, sortOrder: Int.max),
          MatchSheetPlayerEntry(displayName: "Keeper", shirtNumber: 1, sortOrder: Int.max)
        ],
        otherMembers: [
          MatchSheetStaffEntry(displayName: "Analyst", sortOrder: Int.max, category: .otherMember),
          MatchSheetStaffEntry(displayName: "Medic", sortOrder: Int.max, category: .otherMember)
        ],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_710)),
      fallbackTeamName: "Home",
      updatedAt: Date(timeIntervalSince1970: 1_742_000_711))

    try store.save(
      ScheduledMatch(
        homeTeam: "Home",
        awayTeam: "Away",
        homeMatchSheet: homeSheet,
        kickoff: Date()))

    let saved = try XCTUnwrap(store.loadAll().first?.homeMatchSheet)
    XCTAssertEqual(saved.starters.map(\.displayName), ["Late Add", "Captain", "Keeper"])
    XCTAssertEqual(saved.starters.map(\.sortOrder), [0, 1, 2])
    XCTAssertEqual(saved.otherMembers.map(\.displayName), ["Analyst", "Medic"])
    XCTAssertEqual(saved.otherMembers.map(\.sortOrder), [0, 1])
  }

  func testUpsertFromAggregatePreservesMatchSheetsInSnapshot() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))
    let homeSheet = ScheduledMatchSheet(
      sourceTeamName: "Home",
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 1)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_602))
    let awaySheet = ScheduledMatchSheet(
      sourceTeamName: "Away",
      status: .draft,
      starters: [],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_603))

    _ = try store.upsertFromAggregate(
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
        sourceDeviceId: "device"),
      ownerSupabaseId: "owner")

    let saved = try XCTUnwrap(store.loadAll().first)
    XCTAssertEqual(saved.homeMatchSheet, homeSheet.normalized())
    XCTAssertEqual(saved.awayMatchSheet, awaySheet.normalized())
  }

  func testSaveAndLoadPreservesImportedDraftFieldsWithoutWarnings() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))
    let importedSheet = ScheduledMatchSheet(
      sourceTeamId: UUID(),
      sourceTeamName: "Metro FC",
      status: .draft,
      starters: [
        MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, position: "FW", notes: nil, sortOrder: 0),
      ],
      substitutes: [
        MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: nil, position: nil, notes: "Number unreadable", sortOrder: 0),
      ],
      staff: [
        MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 0, category: .staff),
      ],
      otherMembers: [
        MatchSheetStaffEntry(displayName: "Casey Analyst", roleLabel: "Analyst", notes: nil, sortOrder: 0, category: .otherMember),
      ],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_800))

    try store.save(
      ScheduledMatch(
        homeTeam: "Home",
        awayTeam: "Away",
        homeMatchSheet: importedSheet,
        kickoff: Date()))

    let saved = try XCTUnwrap(store.loadAll().first?.homeMatchSheet)
    XCTAssertEqual(saved.status, .draft)
    XCTAssertEqual(saved.sourceTeamName, "Metro FC")
    XCTAssertNotNil(saved.sourceTeamId)
    XCTAssertEqual(saved.substitutes.first?.shirtNumber, nil)
    XCTAssertEqual(saved.substitutes.first?.notes, "Number unreadable")
    XCTAssertEqual(saved.staff.first?.category, .staff)
    XCTAssertEqual(saved.otherMembers.first?.category, .otherMember)
  }

  func testSaveAndLoadPreservesPreparedSideStatusesForOptionalSheets() throws {
    let container = try self.makeContainer()
    let store = SwiftDataScheduleStore(
      container: container,
      auth: SignedInAuth(userId: UUID().uuidString))

    let preparedHome = ScheduledMatchSheet(
      sourceTeamName: "Metro FC",
      status: .draft,
      starters: [MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, sortOrder: 0)],
      substitutes: [MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: 14, sortOrder: 0)],
      staff: [MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Coach", sortOrder: 0, category: .staff)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_810))
      .preparedForScheduleSave()

    let preparedAway = MatchSheetDraftFactory.emptyDraft(teamName: "Rivals FC")
      .preparedForScheduleSave()

    try store.save(
      ScheduledMatch(
        homeTeam: "Metro FC",
        awayTeam: "Rivals FC",
        homeMatchSheet: preparedHome,
        awayMatchSheet: preparedAway,
        kickoff: Date()))

    let saved = try XCTUnwrap(store.loadAll().first)
    XCTAssertEqual(saved.homeMatchSheet?.status, .ready)
    XCTAssertEqual(saved.awayMatchSheet?.status, .draft)
    XCTAssertEqual(saved.awayMatchSheet?.hasAnyEntries, false)
  }

  func testMatchSheetEditorStatePreservesSourceTeamWhenLocalTeamIsMissing() {
    let sourceTeamId = UUID()
    let normalized = MatchSheetEditorState.normalizedSheet(
      ScheduledMatchSheet(
        sourceTeamId: sourceTeamId,
        sourceTeamName: "Archived United",
        status: .draft,
        starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 4)],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_700)),
      fallbackTeamName: "Home Fixture",
      updatedAt: Date(timeIntervalSince1970: 1_742_000_701))

    XCTAssertEqual(normalized.sourceTeamId, sourceTeamId)
    XCTAssertEqual(normalized.sourceTeamName, "Archived United")
    XCTAssertEqual(normalized.starters.map(\.sortOrder), [0])
  }

  func testMatchSheetEditorStateUsesFallbackNameWhenNoSourceProvenanceExists() {
    let normalized = MatchSheetEditorState.normalizedSheet(
      ScheduledMatchSheet(
        status: .draft,
        starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 2)],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_702)),
      fallbackTeamName: "Home Fixture",
      updatedAt: Date(timeIntervalSince1970: 1_742_000_703))

    XCTAssertNil(normalized.sourceTeamId)
    XCTAssertEqual(normalized.sourceTeamName, "Home Fixture")
    XCTAssertEqual(normalized.starters.map(\.sortOrder), [0])
  }

  func testMatchSheetEditorStateReindexesAuthoredOrderBeforeNormalization() {
    let normalized = MatchSheetEditorState.normalizedSheet(
      ScheduledMatchSheet(
        sourceTeamName: "Home",
        status: .draft,
        starters: [
          MatchSheetPlayerEntry(displayName: "Late Add", shirtNumber: nil, sortOrder: Int.max),
          MatchSheetPlayerEntry(displayName: "Captain", shirtNumber: 4, sortOrder: Int.max),
          MatchSheetPlayerEntry(displayName: "Keeper", shirtNumber: 1, sortOrder: Int.max)
        ],
        staff: [
          MatchSheetStaffEntry(displayName: "Trainer", sortOrder: Int.max, category: .staff),
          MatchSheetStaffEntry(displayName: "Coach", sortOrder: Int.max, category: .staff)
        ],
        otherMembers: [
          MatchSheetStaffEntry(displayName: "Analyst", sortOrder: Int.max, category: .otherMember),
          MatchSheetStaffEntry(displayName: "Medic", sortOrder: Int.max, category: .otherMember)
        ],
        updatedAt: Date(timeIntervalSince1970: 1_742_000_704)),
      fallbackTeamName: "Home",
      updatedAt: Date(timeIntervalSince1970: 1_742_000_705))

    XCTAssertEqual(normalized.starters.map(\.displayName), ["Late Add", "Captain", "Keeper"])
    XCTAssertEqual(normalized.starters.map(\.sortOrder), [0, 1, 2])
    XCTAssertEqual(normalized.staff.map(\.displayName), ["Trainer", "Coach"])
    XCTAssertEqual(normalized.staff.map(\.sortOrder), [0, 1])
    XCTAssertEqual(normalized.otherMembers.map(\.displayName), ["Analyst", "Medic"])
    XCTAssertEqual(normalized.otherMembers.map(\.sortOrder), [0, 1])
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
