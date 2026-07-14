import Foundation

struct BackendMatchSheetParseAPI {
  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func parse<Request: Encodable, Response: Decodable>(_ request: Request) async throws -> Response {
    try await client.send(path: "/api/match-sheet/parse", method: .post, body: request)
  }
}
