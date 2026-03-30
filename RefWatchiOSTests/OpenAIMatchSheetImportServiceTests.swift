import XCTest
@testable import RefWatchiOS

final class OpenAIMatchSheetImportServiceTests: XCTestCase {
  func testBuildPayload_whenMultipleImagesProvided_mapsToParserSchema() throws {
    let images = [
      AssistantImageAttachment(
        filename: "sheet-1.jpg",
        jpegData: Data([0x01, 0x02, 0x03]),
        detail: .high,
        pixelWidth: 320,
        pixelHeight: 480),
      AssistantImageAttachment(
        filename: "sheet-2.jpg",
        jpegData: Data([0x04, 0x05, 0x06]),
        detail: .high,
        pixelWidth: 320,
        pixelHeight: 480),
    ]

    let payload = OpenAIMatchSheetImportService.Testing.buildPayload(
      side: .home,
      expectedTeamName: "  Metro FC  ",
      images: images)
    let encoded = try OpenAIMatchSheetImportService.Testing.encodePayload(payload)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let imageArray = try XCTUnwrap(json["images"] as? [[String: Any]])

    XCTAssertEqual(json["side"] as? String, "home")
    XCTAssertEqual(json["expected_team_name"] as? String, "Metro FC")
    XCTAssertEqual(imageArray.count, 2)
    XCTAssertEqual(imageArray[0]["type"] as? String, "input_image")
    XCTAssertEqual(imageArray[0]["detail"] as? String, "high")
    XCTAssertEqual(imageArray[0]["filename"] as? String, "sheet-1.jpg")
    XCTAssertNotNil(imageArray[0]["image_url"] as? String)
    XCTAssertEqual(imageArray[1]["filename"] as? String, "sheet-2.jpg")
  }

  func testBuildRequest_includesSupabaseGatewayHeaders() throws {
    let payload = OpenAIMatchSheetImportService.Testing.buildPayload(
      side: .away,
      expectedTeamName: "Metro FC",
      images: [
        AssistantImageAttachment(
          filename: "sheet.jpg",
          jpegData: Data([0x01, 0x02, 0x03]),
          detail: .high,
          pixelWidth: 320,
          pixelHeight: 480),
      ])
    let environment = SupabaseEnvironment(
      url: try XCTUnwrap(URL(string: "https://muwuzfbtmqwvwacqnofc.supabase.co")),
      anonKey: "sb_publishable_test")

    let request = try OpenAIMatchSheetImportService.buildRequest(
      environment: environment,
      accessToken: "session-token",
      payload: payload)

    XCTAssertEqual(
      request.url?.absoluteString,
      "https://muwuzfbtmqwvwacqnofc.supabase.co/functions/v1/match-sheet-parse")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "sb_publishable_test")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-RefWatch-Client"), "ios")
    XCTAssertNotNil(request.httpBody)
  }
}
