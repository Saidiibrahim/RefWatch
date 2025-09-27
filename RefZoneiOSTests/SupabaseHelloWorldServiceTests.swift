import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseHelloWorldServiceTests: XCTestCase {
  func testFetchMessageReturnsPingResponse() async throws {
    let functions = MockFunctionsClient()
    let client = MockSupabaseClient(functionsClient: functions)
    let provider = MockSupabaseClientProvider(client: client, token: "jwt-token")
    let service = SupabaseHelloWorldService(clientProvider: provider)

    let response = try await service.fetchMessage()

    XCTAssertEqual(response.message, "Supabase connectivity ok — user=mock-user")
    XCTAssertGreaterThanOrEqual(response.latencyMilliseconds, 0)
    XCTAssertEqual(functions.authTokens, ["jwt-token"])
    XCTAssertEqual(provider.clientCallCount, 1)
    XCTAssertEqual(provider.authorizedClientCallCount, 1)
    XCTAssertEqual(functions.invokeCalls.count, 1)
    XCTAssertEqual(functions.invokeCalls.first?.name, "diagnostics-ping")
  }

  func testFetchMessagePropagatesErrors() async {
    let expectedError = TestError()
    let functions = MockFunctionsClient()
    let client = MockSupabaseClient(functionsClient: functions, fetchError: expectedError)
    let provider = MockSupabaseClientProvider(client: client, token: "jwt-token")
    let service = SupabaseHelloWorldService(clientProvider: provider)

    do {
      _ = try await service.fetchMessage()
      XCTFail("Expected to throw")
    } catch let error as TestError {
      XCTAssertTrue(error === expectedError)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(functions.authTokens, ["jwt-token"])
    XCTAssertEqual(provider.clientCallCount, 1)
    XCTAssertEqual(provider.authorizedClientCallCount, 1)
  }
}

private final class MockFunctionsClient: SupabaseFunctionsClientRepresenting {
  var authTokens: [String?] = []
  struct InvokeCall { let name: String }
  private(set) var invokeCalls: [InvokeCall] = []

  func setAuth(token: String?) {
    authTokens.append(token)
  }

  func invoke<T: Decodable>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T {
    invokeCalls.append(.init(name: functionName))
    let payload = MockSupabaseClient.PingPayload(status: "ok", clerk_user_id: "mock-user", timestamp: "2025-09-24T00:00:00Z")
    let data = try JSONEncoder().encode(payload)
    return try decoder.decode(T.self, from: data)
  }
}

private final class MockSupabaseClient: SupabaseClientRepresenting {
  let functionsClient: SupabaseFunctionsClientRepresenting
  struct PingPayload: Codable, Equatable {
    let status: String
    let clerk_user_id: String
    let timestamp: String
  }

  private let fetchError: Error?

  init(
    functionsClient: SupabaseFunctionsClientRepresenting,
    fetchError: Error? = nil
  ) {
    self.functionsClient = functionsClient
    self.fetchError = fetchError
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
    if let fetchError {
      throw fetchError
    }
    return []
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

private final class TestError: Error {}
