import Foundation

struct BackendAssistantAPI {
  private let client: BackendAPIClient

  init(client: BackendAPIClient) {
    self.client = client
  }

  func streamResponse<Request: Encodable>(for request: Request) async throws -> BackendHTTPStream {
    try await client.stream(path: "/api/assistant/responses", body: request)
  }
}
