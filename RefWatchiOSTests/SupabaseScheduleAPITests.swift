import XCTest
@testable import RefWatchiOS
import RefWatchCore

final class SupabaseScheduleAPITests: XCTestCase {
  func testScheduledMatchRowDTODecodesMatchSheets() throws {
    let decoder = SupabaseScheduleAPI.makeDecoder()
    let entryId = UUID()
    let data = Data(
      """
      {
        "id": "\(UUID())",
        "owner_id": "\(UUID())",
        "home_team_name": "Home",
        "away_team_name": "Away",
        "home_match_sheet": {
          "sourceTeamName": "Home",
          "status": "ready",
          "starters": [
            {
              "entryId": "\(entryId.uuidString)",
              "displayName": "Starter",
              "shirtNumber": 9,
              "sortOrder": 1
            }
          ],
          "substitutes": [],
          "staff": [],
          "otherMembers": [],
          "updatedAt": "2025-03-01T10:00:00Z"
        },
        "away_match_sheet": null,
        "kickoff_at": "2025-03-01T11:00:00Z",
        "status": "scheduled",
        "competition_name": "Cup",
        "created_at": "2025-03-01T09:00:00Z",
        "updated_at": "2025-03-01T09:30:00Z"
      }
      """.utf8)

    let row = try decoder.decode(ScheduledMatchRowDTO.self, from: data)

    XCTAssertEqual(row.homeMatchSheet?.status, .ready)
    XCTAssertEqual(row.homeMatchSheet?.starters.first?.entryId, entryId)
    XCTAssertNil(row.awayMatchSheet)
  }

  func testDecodeUpsertResponseHandlesWrappedRepresentationWithMatchSheets() throws {
    let decoder = SupabaseScheduleAPI.makeDecoder()
    let data = Data(
      """
      {
        "data": [
          {
            "id": "\(UUID())",
            "owner_id": "\(UUID())",
            "home_team_name": "Home",
            "away_team_name": "Away",
            "home_match_sheet": {
              "sourceTeamName": "Home",
              "status": "draft",
              "starters": [],
              "substitutes": [],
              "staff": [],
              "otherMembers": [],
              "updatedAt": "2025-03-01T10:00:00Z"
            },
            "kickoff_at": "2025-03-01T11:00:00Z",
            "status": "scheduled",
            "created_at": "2025-03-01T09:00:00Z",
            "updated_at": "2025-03-01T09:30:00Z"
          }
        ]
      }
      """.utf8)

    let rows = try SupabaseScheduleAPI.decodeUpsertResponse(data: data, decoder: decoder)

    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.homeMatchSheet?.status, .draft)
  }
}
