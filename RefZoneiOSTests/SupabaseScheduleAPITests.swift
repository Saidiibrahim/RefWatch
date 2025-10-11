import XCTest
@testable import RefZoneiOS

final class SupabaseScheduleAPITests: XCTestCase {
  func testDecodeUpsertResponseWithPostgresTimestamps() throws {
    let json = """
    [
      {
        "id": "11111111-2222-3333-4444-555555555555",
        "owner_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "home_team_name": "Home",
        "away_team_name": "Away",
        "home_team_id": null,
        "away_team_id": null,
        "kickoff_at": "2025-09-27 04:30:00+00",
        "status": "scheduled",
        "competition_id": null,
        "competition_name": null,
        "venue_id": null,
        "venue_name": null,
        "notes": null,
        "source_device_id": "device-123",
        "created_at": "2025-09-27 09:07:41.499756+00",
        "updated_at": "2025-09-29 00:25:51.888483+00"
      }
    ]
    """.data(using: .utf8)!

    let decoder = SupabaseScheduleAPI.makeDecoder()
    let rows = try SupabaseScheduleAPI.decodeUpsertResponse(data: json, decoder: decoder)

    XCTAssertEqual(rows.count, 1)
    let row = try XCTUnwrap(rows.first)
    XCTAssertEqual(row.id, UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
    XCTAssertEqual(row.ownerId, UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
    XCTAssertEqual(row.homeTeamName, "Home")
    XCTAssertEqual(row.awayTeamName, "Away")
    XCTAssertEqual(row.sourceDeviceId, "device-123")

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    XCTAssertEqual(row.kickoffAt, isoFormatter.date(from: "2025-09-27T04:30:00+00:00"))
    XCTAssertEqual(row.createdAt, isoFormatter.date(from: "2025-09-27T09:07:41.499756+00:00"))
    XCTAssertEqual(row.updatedAt, isoFormatter.date(from: "2025-09-29T00:25:51.888483+00:00"))
  }

  func testDecodeUpsertResponseHandlesWrappedDataPayload() throws {
    let json = """
    {
      "data": [
        {
          "id": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
          "owner_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "home_team_name": "Team A",
          "away_team_name": "Team B",
          "home_team_id": null,
          "away_team_id": null,
          "kickoff_at": "2025-10-01 12:00:00+00",
          "status": "scheduled",
          "competition_id": null,
          "competition_name": null,
          "venue_id": null,
          "venue_name": null,
          "notes": "Semi-final",
          "source_device_id": null,
          "created_at": "2025-09-30 18:00:00+00",
          "updated_at": "2025-09-30 18:05:00+00"
        }
      ]
    }
    """.data(using: .utf8)!

    let decoder = SupabaseScheduleAPI.makeDecoder()
    let rows = try SupabaseScheduleAPI.decodeUpsertResponse(data: json, decoder: decoder)

    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows.first?.notes, "Semi-final")
  }
}
