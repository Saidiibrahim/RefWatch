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

  func testScheduledMatchRowDTODecodesImportedDraftFields() throws {
    let decoder = SupabaseScheduleAPI.makeDecoder()
    let data = Data(
      """
      {
        "id": "\(UUID())",
        "owner_id": "\(UUID())",
        "home_team_name": "Home",
        "away_team_name": "Away",
        "home_match_sheet": {
          "sourceTeamId": "\(UUID())",
          "sourceTeamName": "Metro FC",
          "status": "draft",
          "starters": [
            {
              "displayName": "Alex Starter",
              "shirtNumber": 9,
              "sortOrder": 0
            }
          ],
          "substitutes": [
            {
              "displayName": "Riley Bench",
              "shirtNumber": null,
              "notes": "Number unreadable",
              "sortOrder": 0
            }
          ],
          "staff": [
            {
              "displayName": "Taylor Coach",
              "roleLabel": "Head Coach",
              "category": "staff",
              "sortOrder": 0
            }
          ],
          "otherMembers": [
            {
              "displayName": "Casey Analyst",
              "roleLabel": "Analyst",
              "category": "otherMember",
              "sortOrder": 0
            }
          ],
          "updatedAt": "2025-03-01T10:00:00Z"
        },
        "kickoff_at": "2025-03-01T11:00:00Z",
        "status": "scheduled",
        "created_at": "2025-03-01T09:00:00Z",
        "updated_at": "2025-03-01T09:30:00Z"
      }
      """.utf8)

    let row = try decoder.decode(ScheduledMatchRowDTO.self, from: data)

    XCTAssertEqual(row.homeMatchSheet?.status, .draft)
    XCTAssertEqual(row.homeMatchSheet?.sourceTeamName, "Metro FC")
    XCTAssertEqual(row.homeMatchSheet?.substitutes.first?.shirtNumber, nil)
    XCTAssertEqual(row.homeMatchSheet?.staff.first?.category, .staff)
    XCTAssertEqual(row.homeMatchSheet?.otherMembers.first?.category, .otherMember)
  }

  func testScheduledMatchRowDTODecodesOnePreparedSideAndOneEmptySide() throws {
    let decoder = SupabaseScheduleAPI.makeDecoder()
    let data = Data(
      """
      {
        "id": "\(UUID())",
        "owner_id": "\(UUID())",
        "home_team_name": "Metro FC",
        "away_team_name": "Rivals FC",
        "home_match_sheet": {
          "sourceTeamName": "Metro FC",
          "status": "ready",
          "starters": [
            {
              "displayName": "Alex Starter",
              "shirtNumber": 9,
              "sortOrder": 0
            }
          ],
          "substitutes": [
            {
              "displayName": "Riley Bench",
              "shirtNumber": 14,
              "sortOrder": 0
            }
          ],
          "staff": [
            {
              "displayName": "Taylor Coach",
              "roleLabel": "Coach",
              "category": "staff",
              "sortOrder": 0
            }
          ],
          "otherMembers": [],
          "updatedAt": "2025-03-01T10:00:00Z"
        },
        "away_match_sheet": {
          "sourceTeamName": "Rivals FC",
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
      """.utf8)

    let row = try decoder.decode(ScheduledMatchRowDTO.self, from: data)

    XCTAssertEqual(row.homeMatchSheet?.status, .ready)
    XCTAssertEqual(row.homeMatchSheet?.starterCount, 1)
    XCTAssertEqual(row.awayMatchSheet?.status, .draft)
    XCTAssertEqual(row.awayMatchSheet?.hasAnyEntries, false)
  }
}
