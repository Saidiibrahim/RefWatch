import Foundation

struct BackendJournalAPI {
  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func fetchAssessments<Response: Decodable>(updatedAfter: Date?) async throws -> Response {
    try await client.send(
      path: "/api/match-assessments",
      queryItems: BackendQuery.updatedAfter(updatedAfter))
  }

  func upsertAssessment<Request: Encodable, Response: Decodable>(
    _ request: Request) async throws -> Response
  {
    try await client.send(path: "/api/match-assessments", method: .post, body: request)
  }

  func deleteAssessment(id: String) async throws {
    try await client.sendWithoutResponse(path: "/api/match-assessments/\(id)", method: .delete)
  }
}
