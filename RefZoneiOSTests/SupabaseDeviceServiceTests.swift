import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseDeviceServiceTests: XCTestCase {
  func testUpsertDeviceInvokesFunctionsClient() async throws {
    let functions = MockFunctionsClient()
    let client = MockSupabaseClient(functionsClient: functions)
    let provider = MockSupabaseClientProvider(client: client, token: "jwt-token")
    let service = SupabaseDeviceService(clientProvider: provider)

    let payload = SupabaseDevicePayload(
      id: nil,
      sessionId: "sess-1",
      platform: "iOS",
      model: "iPhone",
      appVersion: "1.0",
      clientName: "Clerk",
      clientVersion: "1.2.3",
      ipAddress: nil,
      location: ["country": "US"],
      userAgent: "RefZoneiOS/1.0 (iPhone; iOS 18.0)",
      lastActiveAt: Date(timeIntervalSince1970: 1_736_000_000),
      metadata: ["build": "42"]
    )

    let response = try await service.upsertDevice(payload: payload)

    XCTAssertEqual(functions.invokeCalls.count, 1)
    XCTAssertEqual(functions.invokeCalls[0].name, "upsert_user_device_from_clerk")
    XCTAssertEqual(functions.lastReceivedBody?.session_id, payload.sessionId)
    XCTAssertEqual(functions.authTokens, ["jwt-token"])
    XCTAssertEqual(provider.clientCallCount, 1)
    XCTAssertEqual(provider.authorizedClientCallCount, 1)
    XCTAssertEqual(response.sessionId, "sess-1")
    XCTAssertEqual(response.platform, "iOS")
    XCTAssertEqual(response.clientName, "Clerk")
    XCTAssertEqual(response.clientVersion, "1.2.3")
  }
}

private final class MockFunctionsClient: SupabaseFunctionsClientRepresenting {
  struct InvokeCall { let name: String }

  var authTokens: [String?] = []
  private(set) var invokeCalls: [InvokeCall] = []
  private(set) var lastReceivedBody: SupabaseDevicePayloadDTO?

  func setAuth(token: String?) {
    authTokens.append(token)
  }

  func invoke<T: Decodable>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T {
    invokeCalls.append(.init(name: functionName))
    if let body = options.body {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      lastReceivedBody = try decoder.decode(SupabaseDevicePayloadDTO.self, from: body)
    }

    let dto = SupabaseDeviceServiceResponseDTO(
      id: UUID(uuidString: "B3258100-0156-45F6-9798-4C199E2BC29E")!,
      user_id: UUID(uuidString: "58BE3095-2B04-43C5-8C2C-22D4FE0C4C79")!,
      session_id: "sess-1",
      platform: "iOS",
      model: "iPhone",
      app_version: "1.0",
      client_name: "Clerk",
      client_version: "1.2.3",
      last_active_at: "2025-09-24T00:00:00Z",
      updated_at: "2025-09-24T00:10:00Z"
    )
    let data = try JSONEncoder().encode(dto)
    return try decoder.decode(T.self, from: data)
  }
}

private struct SupabaseDevicePayloadDTO: Decodable {
  let session_id: String
}

private struct SupabaseDeviceServiceResponseDTO: Encodable {
  let id: UUID
  let user_id: UUID
  let session_id: String
  let platform: String
  let model: String
  let app_version: String
  let client_name: String
  let client_version: String
  let last_active_at: String
  let updated_at: String
}

private final class MockSupabaseClient: SupabaseClientRepresenting {
  let functionsClient: SupabaseFunctionsClientRepresenting

  init(functionsClient: SupabaseFunctionsClientRepresenting) {
    self.functionsClient = functionsClient
  }

  func fetchRows<T>(
    from table: String,
    select columns: String,
    filters: [SupabaseQueryFilter],
    orderBy column: String?,
    ascending: Bool,
    limit: Int,
    decoder: JSONDecoder
  ) async throws -> [T] where T : Decodable {
    []
  }

  func callRPC<Params, Response>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response where Params : Encodable, Response : Decodable {
    throw SupabaseClientError.emptyRPCResponse
  }
}

private final class MockSupabaseClientProvider: SupabaseClientProviding {
  private let client: SupabaseClientRepresenting
  private let token: String
  private let functionToken: String
  private(set) var clientCallCount = 0
  private(set) var authorizedClientCallCount = 0

  init(client: SupabaseClientRepresenting, token: String, functionToken: String? = nil) {
    self.client = client
    self.token = token
    self.functionToken = functionToken ?? token
  }

  func client() throws -> SupabaseClientRepresenting {
    clientCallCount += 1
    return client
  }

  func authorizedClient() async throws -> SupabaseClientRepresenting {
    authorizedClientCallCount += 1
    let resolvedClient = try client()
    resolvedClient.functionsClient.setAuth(token: functionToken)
    return resolvedClient
  }

  func clerkToken() async throws -> String {
    token
  }
}
