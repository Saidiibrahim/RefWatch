import Foundation

struct BackendLibraryAPI {
  enum Resource: String, CaseIterable {
    case teams
    case competitions
    case venues
  }

  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func fetch<Response: Decodable>(
    _ resource: Resource,
    updatedAfter: Date? = nil) async throws -> Response
  {
    try await client.send(
      path: "/api/\(resource.rawValue)",
      queryItems: BackendQuery.updatedAfter(updatedAfter))
  }

  func upsert<Request: Encodable, Response: Decodable>(
    _ resource: Resource,
    request: Request) async throws -> Response
  {
    try await client.send(path: "/api/\(resource.rawValue)", method: .post, body: request)
  }

  func delete(_ resource: Resource, id: String) async throws {
    try await client.sendWithoutResponse(path: "/api/\(resource.rawValue)/\(id)", method: .delete)
  }
}
