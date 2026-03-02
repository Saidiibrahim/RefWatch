import XCTest
@testable import RefWatchCore

@MainActor
final class CardDetailsTests: XCTestCase {
  func test_secondCautionDetection_usesReasonCode() {
    let details = CardDetails(
      cardType: .red,
      recipientType: .player,
      playerNumber: 9,
      playerName: nil,
      officialRole: nil,
      reason: "R7 – Second Yellow",
      reasonCode: "R7",
      reasonTitle: "Second Yellow")

    XCTAssertTrue(details.isSecondCautionDismissal)
  }

  func test_secondCautionDetection_usesReasonTextFallback() {
    let details = CardDetails(
      cardType: .red,
      recipientType: .player,
      playerNumber: 5,
      playerName: nil,
      officialRole: nil,
      reason: "Second caution for persistent dissent")

    XCTAssertTrue(details.isSecondCautionDismissal)
  }

  func test_legacyCardDetailsDecoding_withoutReasonCodeFields() throws {
    let decoder = JSONDecoder()
    let json = """
    {
      "cardType": "Yellow",
      "recipientType": "Player",
      "playerNumber": 8,
      "playerName": null,
      "officialRole": null,
      "reason": "Y1 – Unsporting Behaviour"
    }
    """

    let details = try decoder.decode(CardDetails.self, from: Data(json.utf8))
    XCTAssertEqual(details.cardType, .yellow)
    XCTAssertEqual(details.reasonCode, nil)
    XCTAssertEqual(details.reasonTitle, nil)
  }

  func test_matchViewModel_recordCardPersistsReasonMetadata() {
    let vm = MatchViewModel()
    vm.configureMatch(duration: 45, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    vm.startMatch()

    vm.recordCard(
      team: .home,
      cardType: .red,
      recipientType: .player,
      playerNumber: 3,
      reason: "R7 – Second Yellow",
      reasonCode: "R7",
      reasonTitle: "Second Yellow")

    guard let last = vm.matchEvents.last else {
      return XCTFail("Expected recorded card event")
    }

    guard case let .card(details) = last.eventType else {
      return XCTFail("Expected card event")
    }

    XCTAssertEqual(details.reasonCode, "R7")
    XCTAssertEqual(details.reasonTitle, "Second Yellow")
    XCTAssertTrue(details.isSecondCautionDismissal)
  }
}
