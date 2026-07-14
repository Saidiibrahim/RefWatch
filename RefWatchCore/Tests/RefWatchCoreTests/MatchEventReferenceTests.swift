import Foundation
import XCTest
@testable import RefWatchCore

final class MatchEventReferenceTests: XCTestCase {
  func testRoundTripPreservesOptionalTeamReferences() throws {
    let teamId = UUID()
    let teamMemberId = UUID()
    let event = MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 2),
      matchTime: "00:10",
      period: 1,
      eventType: .kickOff,
      team: .home,
      teamId: teamId,
      teamMemberId: teamMemberId,
      details: .general)

    let decoded = try JSONDecoder().decode(
      MatchEventRecord.self,
      from: JSONEncoder().encode(event))

    XCTAssertEqual(decoded.teamId, teamId)
    XCTAssertEqual(decoded.teamMemberId, teamMemberId)
  }

  func testLegacyPayloadWithoutTeamReferencesStillDecodes() throws {
    let event = MatchEventRecord(
      id: UUID(),
      timestamp: Date(timeIntervalSince1970: 1),
      actualTime: Date(timeIntervalSince1970: 2),
      matchTime: "00:10",
      period: 1,
      eventType: .kickOff,
      team: .home,
      details: .general)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
    object.removeValue(forKey: "teamId")
    object.removeValue(forKey: "teamMemberId")

    let decoded = try JSONDecoder().decode(
      MatchEventRecord.self,
      from: JSONSerialization.data(withJSONObject: object))

    XCTAssertNil(decoded.teamId)
    XCTAssertNil(decoded.teamMemberId)
  }
}
