import Foundation

struct BackendScheduleAPI {
  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func fetch<Response: Decodable>(updatedAfter: Date?) async throws -> Response {
    try await client.send(
      path: "/api/scheduled-matches",
      queryItems: BackendQuery.updatedAfter(updatedAfter))
  }

  func upsert<Request: Encodable, Response: Decodable>(_ request: Request) async throws -> Response {
    try await client.send(path: "/api/scheduled-matches", method: .post, body: request)
  }

  func delete(id: String) async throws {
    try await client.sendWithoutResponse(path: "/api/scheduled-matches/\(id)", method: .delete)
  }
}
