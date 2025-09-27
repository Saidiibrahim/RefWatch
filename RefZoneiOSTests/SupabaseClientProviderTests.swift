import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseClientProviderTests: XCTestCase {
  func testAuthorizedClientSetsFunctionsAuthForEachCall() async throws {
    let functions = RecordingFunctionsClient()
    var factoryCallCount = 0

    let provider = SupabaseClientProvider(
      environmentLoader: { SupabaseEnvironment(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key") },
      clientFactory: { environment in
        XCTAssertEqual(environment.url.host, "example.supabase.co")
        factoryCallCount += 1
        return RecordingSupabaseClient(functionsClient: functions)
      }
    )

    _ = try await provider.authorizedClient()
    _ = try await provider.authorizedClient()

    XCTAssertEqual(functions.authTokens, ["anon-key", "anon-key"])
    XCTAssertEqual(factoryCallCount, 1, "Client factory should only build once and reuse cached client")
  }
}

private struct TestError: Error {}

private final class RecordingSupabaseClient: SupabaseClientRepresenting {
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
  ) async throws -> [T] where T: Decodable {
    return []
  }

  func callRPC<Params, Response>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response where Params : Encodable, Response : Decodable {
    fatalError("RPC should not be called in client provider tests")
  }

  func upsertRows<Payload, Response>(
    into table: String,
    payload: Payload,
    onConflict: String,
    decoder: JSONDecoder
  ) async throws -> Response where Payload : Encodable, Response : Decodable {
    fatalError("upsertRows should not be called in client provider tests")
  }
}

private final class RecordingFunctionsClient: SupabaseFunctionsClientRepresenting {
  private(set) var authTokens: [String] = []

  func setAuth(token: String?) {
    authTokens.append(token ?? "<nil>")
  }

  func invoke<T>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T where T: Decodable {
    XCTFail("invoke should not be called in SupabaseClientProvider authorization tests")
    throw TestError()
  }
}
