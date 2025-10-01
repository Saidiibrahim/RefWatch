import Foundation
import XCTest
@testable import RefZoneiOS

final class SupabaseMatchIngestServiceTests: XCTestCase {
  func testMakeDecoder_decodesSyncResultWithFractionalSeconds() throws {
    let updatedAt = "2025-09-30T09:16:42.448Z"
    let result = try decodeSyncResult(updatedAt: updatedAt)

    XCTAssertEqual(result.matchId, matchId)
    XCTAssertEqual(result.updatedAt, parseExpectedDate(updatedAt))
  }

  func testMakeDecoder_decodesSyncResultWithoutFractionalSeconds() throws {
    let updatedAt = "2025-09-30T09:16:42Z"
    let result = try decodeSyncResult(updatedAt: updatedAt)

    XCTAssertEqual(result.updatedAt, parseExpectedDate(updatedAt))
  }

  func testMakeDecoder_decodesSyncResultWithPostgresStyleOffset() throws {
    let updatedAt = "2025-09-30 09:16:42.448+0000"
    let result = try decodeSyncResult(updatedAt: updatedAt)

    XCTAssertEqual(result.updatedAt, parseExpectedDate("2025-09-30T09:16:42.448+00:00"))
  }
 }

private extension SupabaseMatchIngestServiceTests {
  var matchId: UUID { UUID(uuidString: "2F932DF8-EDA5-4B09-BF7C-E8CFECF8F7D0")! }

  func decodeSyncResult(updatedAt: String) throws -> SupabaseMatchIngestService.SyncResult {
    let decoder = SupabaseMatchIngestService.makeDecoder()
    let payload: [String: Any] = [
      "match_id": matchId.uuidString,
      "updated_at": updatedAt
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    return try decoder.decode(SupabaseMatchIngestService.SyncResult.self, from: data)
  }

  func parseExpectedDate(_ value: String) -> Date {
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithoutFraction = ISO8601DateFormatter()
    isoWithoutFraction.formatOptions = [.withInternetDateTime]

    guard let date = SupabaseDateParser.parse(
      value,
      isoWithFraction: isoWithFraction,
      isoWithoutFraction: isoWithoutFraction
    ) else {
      XCTFail("Failed to parse expected date for value \(value)")
      return Date(timeIntervalSince1970: 0)
    }

    return date
  }
}
