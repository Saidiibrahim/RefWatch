import XCTest
@testable import RefWatchCore

final class CompletedMatchRecordsTests: XCTestCase {
  func test_matchRecordsSections_useRequiredOrder_andPreserveEventOrderWithinSections() {
    let snapshot = CompletedMatch(
      match: Match(homeTeam: "Home", awayTeam: "Away"),
      events: [
        self.goalEvent(time: "05:00", team: .home, playerNumber: 9, playerName: "Nine"),
        self.cardEvent(time: "06:00", team: .home, cardType: .red, playerNumber: 4, reason: "DOGSO"),
        self.cardEvent(time: "07:00", team: .home, cardType: .yellow, playerNumber: 8, reason: "UB"),
        self.substitutionEvent(time: "08:00", team: .home, playerOut: 3, playerIn: 14),
        self.goalEvent(time: "09:00", team: .away, playerNumber: 10, playerName: "Ten"),
        self.generalEvent(time: "10:00"),
      ])

    let sections = snapshot.matchRecordsSections(for: .home)

    XCTAssertEqual(sections.map(\.kind), [.goals, .cards, .substitutions])
    XCTAssertEqual(sections[0].events.map(\.matchTime), ["05:00"])
    XCTAssertEqual(sections[1].events.map(\.matchTime), ["07:00", "06:00"])
    XCTAssertEqual(sections[2].events.map(\.matchTime), ["08:00"])
  }

  func test_matchRecordsSections_preserveRecordedTeam_forOwnGoals() {
    let snapshot = CompletedMatch(
      match: Match(homeTeam: "Home", awayTeam: "Away"),
      events: [
        self.goalEvent(
          time: "42:00",
          team: .away,
          playerNumber: 5,
          playerName: "Defender",
          goalType: .ownGoal),
      ])

    XCTAssertEqual(snapshot.matchRecordsSections(for: .home).count, 0)
    XCTAssertEqual(snapshot.matchRecordsSections(for: .away).first?.events.map(\.matchTime), ["42:00"])
  }

  func test_matchRecordsSections_excludePenaltyShootoutAndLifecycleEvents() {
    let snapshot = CompletedMatch(
      match: Match(homeTeam: "Home", awayTeam: "Away"),
      events: [
        self.generalEvent(time: "00:00", eventType: .kickOff),
        self.goalEvent(time: "12:00", team: .home, playerNumber: 9, playerName: "Nine"),
        self.penaltyAttemptEvent(time: "90:00", team: .home, playerNumber: 9, result: .scored),
        self.generalEvent(time: "90:01", eventType: .penaltiesStart),
        self.substitutionEvent(time: "91:00", team: .home, playerOut: 4, playerIn: 14),
        self.generalEvent(time: "120:00", eventType: .matchEnd),
      ])

    let sections = snapshot.matchRecordsSections(for: .home)

    XCTAssertEqual(sections.map(\.kind), [.goals, .substitutions])
    XCTAssertEqual(sections.flatMap(\.events).map(\.matchTime), ["12:00", "91:00"])
  }

  func test_matchRecordsSections_returnEmpty_forScoreOnlySummaries() {
    let snapshot = CompletedMatch(
      match: Match(homeTeam: "Home", awayTeam: "Away"),
      events: [])

    XCTAssertEqual(snapshot.matchRecordsSections(for: .home), [])
    XCTAssertEqual(snapshot.matchRecordsSections(for: .away), [])
  }
}

private extension CompletedMatchRecordsTests {
  func goalEvent(
    time: String,
    team: TeamSide,
    playerNumber: Int?,
    playerName: String?,
    goalType: GoalDetails.GoalType = .regular) -> MatchEventRecord
  {
    let details = GoalDetails(goalType: goalType, playerNumber: playerNumber, playerName: playerName)
    return MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 1),
      matchTime: time,
      period: 1,
      eventType: .goal(details),
      team: team,
      details: .goal(details))
  }

  func cardEvent(
    time: String,
    team: TeamSide,
    cardType: CardDetails.CardType,
    playerNumber: Int?,
    reason: String) -> MatchEventRecord
  {
    let details = CardDetails(
      cardType: cardType,
      recipientType: .player,
      playerNumber: playerNumber,
      playerName: nil,
      officialRole: nil,
      reason: reason)
    return MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 1),
      matchTime: time,
      period: 1,
      eventType: .card(details),
      team: team,
      details: .card(details))
  }

  func substitutionEvent(
    time: String,
    team: TeamSide,
    playerOut: Int?,
    playerIn: Int?) -> MatchEventRecord
  {
    let details = SubstitutionDetails(
      playerOut: playerOut,
      playerIn: playerIn,
      playerOutName: nil,
      playerInName: nil)
    return MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 1),
      matchTime: time,
      period: 1,
      eventType: .substitution(details),
      team: team,
      details: .substitution(details))
  }

  func generalEvent(time: String) -> MatchEventRecord {
    self.generalEvent(time: time, eventType: .matchEnd)
  }

  func generalEvent(time: String, eventType: MatchEventType) -> MatchEventRecord {
    MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 1),
      matchTime: time,
      period: 1,
      eventType: eventType,
      team: nil,
      details: .general)
  }

  func penaltyAttemptEvent(
    time: String,
    team: TeamSide,
    playerNumber: Int?,
    result: PenaltyAttemptDetails.Result) -> MatchEventRecord
  {
    let details = PenaltyAttemptDetails(result: result, playerNumber: playerNumber, round: 1)
    return MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 1),
      matchTime: time,
      period: 5,
      eventType: .penaltyAttempt(details),
      team: team,
      details: .penalty(details))
  }
}
