import Foundation

struct BackendMatchIngestService {
  struct SyncResult: Decodable, Equatable, Sendable {
    let matchId: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
      case matchId = "match_id"
      case updatedAt = "updated_at"
    }
  }

  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func ingest<Request: Encodable>(
    _ request: Request,
    idempotencyKey: String? = nil) async throws -> SyncResult
  {
    try await client.send(
      path: "/api/matches/ingest",
      method: .post,
      body: request,
      idempotencyKey: idempotencyKey)
  }

  func fetch<Response: Decodable>(updatedAfter: Date?) async throws -> Response {
    try await client.send(
      path: "/api/matches",
      queryItems: BackendQuery.updatedAfter(updatedAfter))
  }

  func delete(id: String) async throws {
    try await client.sendWithoutResponse(path: "/api/matches/\(id)", method: .delete)
  }
}
