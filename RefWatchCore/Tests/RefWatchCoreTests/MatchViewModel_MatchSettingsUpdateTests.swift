import XCTest
@testable import RefWatchCore

@MainActor
private final class MockHistoryService: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {}
  func delete(id: UUID) throws {}
  func wipeAll() throws {}
}

@MainActor
final class MatchViewModel_MatchSettingsUpdateTests: XCTestCase {
  func test_applySettingsToCurrentMatch_preserves_existing_state() {
    let viewModel = MatchViewModel(history: MockHistoryService())

    var existingMatch = Match(
      homeTeam: "Home FC",
      awayTeam: "Away FC",
      duration: TimeInterval(80 * 60),
      numberOfPeriods: 2,
      halfTimeLength: TimeInterval(10 * 60),
      extraTimeHalfLength: TimeInterval(5 * 60),
      hasExtraTime: false,
      hasPenalties: false,
      penaltyInitialRounds: 3)
    existingMatch.homeScore = 2
    existingMatch.awayScore = 1
    existingMatch.homeYellowCards = 1
    existingMatch.awayRedCards = 1

    viewModel.currentMatch = existingMatch
    viewModel.matchDuration = 80
    viewModel.numberOfPeriods = 2
    viewModel.halfTimeLength = 10
    viewModel.hasExtraTime = false
    viewModel.hasPenalties = false
    viewModel.extraTimeHalfLengthMinutes = 5
    viewModel.penaltyInitialRounds = 3

    let settings = MatchViewModel.MatchSettings(
      durationMinutes: 100,
      periods: 3,
      halfTimeLengthMinutes: 12,
      hasExtraTime: true,
      hasPenalties: true,
      extraTimeHalfLengthMinutes: 10,
      penaltyRounds: 7)
    viewModel.applySettingsToCurrentMatch(settings)

    guard let updatedMatch = viewModel.currentMatch else {
      XCTFail("Expected current match to be preserved")
      return
    }

    XCTAssertEqual(updatedMatch.homeTeam, "Home FC")
    XCTAssertEqual(updatedMatch.awayTeam, "Away FC")
    XCTAssertEqual(updatedMatch.homeScore, 2)
    XCTAssertEqual(updatedMatch.awayScore, 1)
    XCTAssertEqual(updatedMatch.homeYellowCards, 1)
    XCTAssertEqual(updatedMatch.awayRedCards, 1)

    XCTAssertEqual(updatedMatch.duration, TimeInterval(100 * 60))
    XCTAssertEqual(updatedMatch.numberOfPeriods, 3)
    XCTAssertEqual(updatedMatch.halfTimeLength, TimeInterval(12 * 60))
    XCTAssertEqual(updatedMatch.extraTimeHalfLength, TimeInterval(10 * 60))
    XCTAssertTrue(updatedMatch.hasExtraTime)
    XCTAssertTrue(updatedMatch.hasPenalties)
    XCTAssertEqual(updatedMatch.penaltyInitialRounds, 7)

    XCTAssertEqual(viewModel.matchDuration, 100)
    XCTAssertEqual(viewModel.numberOfPeriods, 3)
    XCTAssertEqual(viewModel.halfTimeLength, 12)
    XCTAssertTrue(viewModel.hasExtraTime)
    XCTAssertTrue(viewModel.hasPenalties)
    XCTAssertEqual(viewModel.extraTimeHalfLengthMinutes, 10)
    XCTAssertEqual(viewModel.penaltyInitialRounds, 7)
  }
}
