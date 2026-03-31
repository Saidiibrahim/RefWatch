import XCTest
@testable import RefWatchCore

final class ScheduledMatchSheetTests: XCTestCase {
  func testNormalizedDemotesInvalidReadySheetAndNormalizesOrdering() {
    let sheet = ScheduledMatchSheet(
      sourceTeamName: "  Metro FC  ",
      status: .ready,
      starters: [
        MatchSheetPlayerEntry(displayName: "  ", shirtNumber: 11, position: " ST ", notes: "  ", sortOrder: 2),
        MatchSheetPlayerEntry(displayName: " Alex ", shirtNumber: 9, position: " FW ", notes: " Captain ", sortOrder: 1),
      ],
      substitutes: [
        MatchSheetPlayerEntry(displayName: "  Ben  ", shirtNumber: 18, position: " MF ", notes: "  Impact  ", sortOrder: 3),
        MatchSheetPlayerEntry(displayName: "Chris", shirtNumber: 14, position: nil, notes: nil, sortOrder: 1),
      ],
      staff: [
        MatchSheetStaffEntry(displayName: "Taylor", roleLabel: "Coach", notes: nil, sortOrder: 2, category: .otherMember),
      ],
      otherMembers: [
        MatchSheetStaffEntry(displayName: " Jordan ", roleLabel: " Analyst ", notes: "  ", sortOrder: 1, category: .staff),
      ],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_000))

    let normalized = sheet.normalized()

    XCTAssertEqual(normalized.sourceTeamName, "Metro FC")
    XCTAssertEqual(normalized.status, .draft)
    XCTAssertEqual(normalized.starters.map(\.displayName), ["Alex", ""])
    XCTAssertEqual(normalized.starters.map(\.shirtNumber), [9, 11])
    XCTAssertEqual(normalized.starters.map(\.sortOrder), [0, 1])
    XCTAssertEqual(normalized.substitutes.map(\.displayName), ["Chris", "Ben"])
    XCTAssertEqual(normalized.substitutes.map(\.shirtNumber), [14, 18])
    XCTAssertEqual(normalized.substitutes.map(\.sortOrder), [0, 1])
    XCTAssertEqual(normalized.substitutes.last?.notes, "Impact")
    XCTAssertEqual(normalized.staff.first?.category, .staff)
    XCTAssertEqual(normalized.staff.map(\.sortOrder), [0])
    XCTAssertEqual(normalized.otherMembers.first?.category, .otherMember)
    XCTAssertEqual(normalized.otherMembers.first?.roleLabel, "Analyst")
    XCTAssertEqual(normalized.otherMembers.map(\.sortOrder), [0])
    XCTAssertFalse(normalized.isReady)
  }

  func testLineupResolverUsesReadySheetAndSubstitutionHistory() {
    let starterA = MatchSheetPlayerEntry(displayName: "Starter A", shirtNumber: 4, sortOrder: 1)
    let starterB = MatchSheetPlayerEntry(displayName: "Starter B", shirtNumber: 8, sortOrder: 2)
    let substituteA = MatchSheetPlayerEntry(displayName: "Sub A", shirtNumber: 12, sortOrder: 3)
    let substituteB = MatchSheetPlayerEntry(displayName: "Sub B", shirtNumber: 15, sortOrder: 4)
    let sheet = ScheduledMatchSheet(
      status: .ready,
      starters: [starterB, starterA],
      substitutes: [substituteB, substituteA],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_100))

    let substitution = MatchEventRecord(
      matchTime: "55:00",
      period: 2,
      eventType: .substitution(
        SubstitutionDetails(
          playerOut: 8,
          playerIn: 12,
          playerOutName: "Starter B",
          playerInName: "Sub A")),
      team: .home,
      details: .substitution(
        SubstitutionDetails(
          playerOut: 8,
          playerIn: 12,
          playerOutName: "Starter B",
          playerInName: "Sub A")))

    let resolved = MatchSheetLineupResolver.resolve(sheet: sheet, team: .home, events: [substitution])

    XCTAssertEqual(resolved?.onField.map(\.displayName), ["Starter A", "Sub A"])
    XCTAssertEqual(resolved?.unusedSubstitutes.map(\.displayName), ["Sub B"])
  }

  func testLineupResolverReturnsNilForDraftSheet() {
    let sheet = ScheduledMatchSheet(
      status: .draft,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 7, sortOrder: 1)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_200))

    XCTAssertNil(MatchSheetLineupResolver.resolve(sheet: sheet, team: .away, events: []))
  }

  func testLineupResolverRemovesDismissedPlayersFromOfficialOptions() {
    let starterA = MatchSheetPlayerEntry(displayName: "Starter A", shirtNumber: 4, sortOrder: 1)
    let starterB = MatchSheetPlayerEntry(displayName: "Starter B", shirtNumber: 8, sortOrder: 2)
    let substituteA = MatchSheetPlayerEntry(displayName: "Sub A", shirtNumber: 12, sortOrder: 3)
    let substituteB = MatchSheetPlayerEntry(displayName: "Sub B", shirtNumber: 15, sortOrder: 4)
    let sheet = ScheduledMatchSheet(
      status: .ready,
      starters: [starterA, starterB],
      substitutes: [substituteA, substituteB],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_250))

    let dismissal = MatchEventRecord(
      matchTime: "60:00",
      period: 2,
      eventType: .card(
        CardDetails(
          cardType: .red,
          recipientType: .player,
          playerNumber: 8,
          playerName: "Starter B",
          officialRole: nil,
          reason: "Serious foul play")),
      team: .home,
      details: .card(
        CardDetails(
          cardType: .red,
          recipientType: .player,
          playerNumber: 8,
          playerName: "Starter B",
          officialRole: nil,
          reason: "Serious foul play")))

    let substituteDismissal = MatchEventRecord(
      matchTime: "61:00",
      period: 2,
      eventType: .card(
        CardDetails(
          cardType: .red,
          recipientType: .player,
          playerNumber: 15,
          playerName: "Sub B",
          officialRole: nil,
          reason: "Violent conduct")),
      team: .home,
      details: .card(
        CardDetails(
          cardType: .red,
          recipientType: .player,
          playerNumber: 15,
          playerName: "Sub B",
          officialRole: nil,
          reason: "Violent conduct")))

    let resolved = MatchSheetLineupResolver.resolve(
      sheet: sheet,
      team: .home,
      events: [dismissal, substituteDismissal])

    XCTAssertEqual(resolved?.onField.map(\.displayName), ["Starter A"])
    XCTAssertEqual(resolved?.unusedSubstitutes.map(\.displayName), ["Sub A"])
  }

  func testSelectionResolverPrefersReadyFrozenSheetsOverLegacyRoster() {
    let readySheet = ScheduledMatchSheet(
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Frozen Starter", shirtNumber: 9, sortOrder: 1)],
      substitutes: [MatchSheetPlayerEntry(displayName: "Frozen Sub", shirtNumber: 18, sortOrder: 2)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_300))
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeTeamId: UUID(),
      awayTeamId: UUID(),
      homeMatchSheet: readySheet,
      awayMatchSheet: readySheet)
    let libraryTeam = MatchLibraryTeam(
      id: match.homeTeamId ?? UUID(),
      name: "Metro FC",
      players: [MatchLibraryPlayer(id: UUID(), name: "Legacy Player", number: 4)])

    let resolved = MatchParticipantSelectionResolver.resolve(
      match: match,
      team: .home,
      libraryTeams: [libraryTeam],
      events: [])

    guard case let .frozenSheet(lineup) = resolved else {
      return XCTFail("Expected frozen sheet precedence")
    }
    XCTAssertEqual(lineup.onField.map { $0.displayName }, ["Frozen Starter"])
  }

  func testSelectionResolverFallsBackToManualWhenExplicitSheetIsNotReady() {
    let draftSheet = ScheduledMatchSheet(
      status: .draft,
      starters: [MatchSheetPlayerEntry(displayName: "Draft Starter", shirtNumber: 9, sortOrder: 1)],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_400))
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeTeamId: UUID(),
      awayTeamId: UUID(),
      homeMatchSheet: draftSheet,
      awayMatchSheet: nil)
    let libraryTeam = MatchLibraryTeam(
      id: match.homeTeamId ?? UUID(),
      name: "Metro FC",
      players: [MatchLibraryPlayer(id: UUID(), name: "Legacy Player", number: 4)])

    let resolved = MatchParticipantSelectionResolver.resolve(
      match: match,
      team: .home,
      libraryTeams: [libraryTeam],
      events: [])

    XCTAssertEqual(resolved, MatchParticipantSelectionSource.manualOnly)
  }

  func testSelectionResolverUsesLegacyRosterOnlyWhenNoSheetModelExists() {
    let homeTeamId = UUID()
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeTeamId: homeTeamId,
      awayTeamId: UUID())
    let legacyPlayer = MatchLibraryPlayer(id: UUID(), name: "Legacy Player", number: 4)
    let libraryTeam = MatchLibraryTeam(id: homeTeamId, name: "Metro FC", players: [legacyPlayer])

    let resolved = MatchParticipantSelectionResolver.resolve(
      match: match,
      team: .home,
      libraryTeams: [libraryTeam],
      events: [])

    XCTAssertEqual(resolved, MatchParticipantSelectionSource.legacyLibrary(players: [legacyPlayer]))
  }

  func testPreparedForScheduleSavePromotesCompleteSideAndKeepsEmptySideDraft() {
    let completeSheet = ScheduledMatchSheet(
      sourceTeamName: "Metro FC",
      status: .draft,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 0)],
      substitutes: [MatchSheetPlayerEntry(displayName: "Bench", shirtNumber: 14, sortOrder: 0)],
      staff: [MatchSheetStaffEntry(displayName: "Coach", roleLabel: "Coach", sortOrder: 0, category: .staff)],
      updatedAt: Date(timeIntervalSince1970: 1_742_001_000))

    let emptySheet = ScheduledMatchSheet(sourceTeamName: "Rivals", status: .ready, updatedAt: Date(timeIntervalSince1970: 1_742_001_001))

    XCTAssertEqual(completeSheet.preparedForScheduleSave().status, .ready)
    XCTAssertEqual(emptySheet.preparedForScheduleSave().status, .draft)
  }

  func testSelectionResolverUsesReadySideEvenWhenOppositeSideIsMissing() {
    let readySheet = ScheduledMatchSheet(
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Frozen Starter", shirtNumber: 9, sortOrder: 0)],
      updatedAt: Date(timeIntervalSince1970: 1_742_001_100))
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeMatchSheet: readySheet,
      awayMatchSheet: nil)

    let resolved = MatchParticipantSelectionResolver.resolve(
      match: match,
      team: .home,
      libraryTeams: [],
      events: [])

    guard case let .frozenSheet(lineup) = resolved else {
      return XCTFail("Expected per-side saved sheet precedence")
    }

    XCTAssertEqual(lineup.onField.map(\.displayName), ["Frozen Starter"])
  }

  func testSelectionResolverUsesManualFallbackWhenOnlyOppositeSideHasSavedSheet() {
    let readySheet = ScheduledMatchSheet(
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Frozen Starter", shirtNumber: 9, sortOrder: 0)],
      updatedAt: Date(timeIntervalSince1970: 1_742_001_200))
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeMatchSheet: readySheet,
      awayMatchSheet: nil)

    let resolved = MatchParticipantSelectionResolver.resolve(
      match: match,
      team: .away,
      libraryTeams: [
        MatchLibraryTeam(id: UUID(), name: "Rivals", players: [MatchLibraryPlayer(id: UUID(), name: "Legacy Player", number: 4)])
      ],
      events: [])

    XCTAssertEqual(resolved, .manualOnly)
  }

  func testCardResolversUsePerSideSavedParticipants() {
    let readySheet = ScheduledMatchSheet(
      status: .ready,
      starters: [MatchSheetPlayerEntry(displayName: "Starter", shirtNumber: 9, sortOrder: 0)],
      substitutes: [MatchSheetPlayerEntry(displayName: "Bench", shirtNumber: 14, sortOrder: 0)],
      staff: [MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Coach", sortOrder: 0, category: .staff)],
      otherMembers: [MatchSheetStaffEntry(displayName: "Casey Analyst", roleLabel: "Analyst", sortOrder: 0, category: .otherMember)],
      updatedAt: Date(timeIntervalSince1970: 1_742_001_300))
    let match = Match(
      homeTeam: "Metro FC",
      awayTeam: "Rivals",
      duration: 90 * 60,
      halfTimeLength: 15 * 60,
      homeMatchSheet: readySheet,
      awayMatchSheet: nil)

    let playerSource = MatchParticipantSelectionResolver.resolveCardPlayers(
      match: match,
      team: .home,
      libraryTeams: [],
      events: [])
    let officialSource = MatchParticipantSelectionResolver.resolveCardOfficials(
      match: match,
      team: .home)

    guard case let .savedSheet(players) = playerSource else {
      return XCTFail("Expected saved player source")
    }
    guard case let .savedSheet(officials) = officialSource else {
      return XCTFail("Expected saved official source")
    }

    XCTAssertEqual(players.map(\.displayName), ["Starter", "Bench"])
    XCTAssertEqual(players.map(\.shirtNumber), [9, 14])
    XCTAssertEqual(officials.map(\.displayName), ["Taylor Coach", "Casey Analyst"])
  }

  func testDecodeBackwardCompatibleSheetUsesDefaultsForMissingFieldsAndUnknownEnums() throws {
    let data = """
    {
      "sourceTeamName": "Legacy FC",
      "status": "unexpected",
      "starters": [
        {
          "displayName": "Starter One"
        }
      ],
      "staff": [
        {
          "displayName": "Coach One",
          "category": "mystery"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(ScheduledMatchSheet.self, from: data)

    XCTAssertEqual(decoded.sourceTeamName, "Legacy FC")
    XCTAssertEqual(decoded.status, .draft)
    XCTAssertEqual(decoded.starters.first?.displayName, "Starter One")
    XCTAssertEqual(decoded.starters.first?.sortOrder, 0)
    XCTAssertEqual(decoded.staff.first?.category, .staff)
    XCTAssertTrue(decoded.substitutes.isEmpty)
    XCTAssertTrue(decoded.otherMembers.isEmpty)
  }

  func testImportedDraftKeepsNilNumbersAndNormalizesStaffBuckets() {
    let sheet = ScheduledMatchSheet(
      sourceTeamName: "Metro FC",
      status: .draft,
      starters: [
        MatchSheetPlayerEntry(displayName: "Alex Starter", shirtNumber: 9, position: "FW", notes: nil, sortOrder: 3),
      ],
      substitutes: [
        MatchSheetPlayerEntry(displayName: "Riley Bench", shirtNumber: nil, position: nil, notes: "Number unreadable", sortOrder: 8),
      ],
      staff: [
        MatchSheetStaffEntry(displayName: "Taylor Coach", roleLabel: "Head Coach", notes: nil, sortOrder: 7, category: .otherMember),
      ],
      otherMembers: [
        MatchSheetStaffEntry(displayName: "Casey Analyst", roleLabel: "Analyst", notes: nil, sortOrder: 5, category: .staff),
      ],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_900))

    let normalized = sheet.normalized()

    XCTAssertEqual(normalized.status, .draft)
    XCTAssertEqual(normalized.substitutes.first?.shirtNumber, nil)
    XCTAssertEqual(normalized.substitutes.first?.notes, "Number unreadable")
    XCTAssertEqual(normalized.staff.first?.category, .staff)
    XCTAssertEqual(normalized.otherMembers.first?.category, .otherMember)
    XCTAssertEqual(normalized.starters.first?.sortOrder, 0)
    XCTAssertEqual(normalized.substitutes.first?.sortOrder, 0)
  }
}
