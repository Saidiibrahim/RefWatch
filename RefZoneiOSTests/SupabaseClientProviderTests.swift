import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseClientProviderTests: XCTestCase {
  func testAuthorizedClientSetsFunctionsAuthForEachCall() async throws {
    let functions = RecordingFunctionsClient()
    let tokenProvider = MockTokenProvider(tokens: ["token-1", "token-2"])
    var factoryCallCount = 0

    let provider = SupabaseClientProvider(
      environmentLoader: { SupabaseEnvironment(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key") },
      tokenProvider: tokenProvider,
      clientFactory: { environment, _ in
        XCTAssertEqual(environment.url.host, "example.supabase.co")
        factoryCallCount += 1
        return RecordingSupabaseClient(functionsClient: functions)
      }
    )

    _ = try await provider.authorizedClient()
    _ = try await provider.authorizedClient()

    XCTAssertTrue(tokenProvider.requestedTokens.isEmpty)
    XCTAssertEqual(functions.authTokens, ["anon-key", "anon-key"])
    XCTAssertEqual(factoryCallCount, 1, "Client factory should only build once and reuse cached client")
  }

  func testClerkTokenPropagatesErrors() async {
    let functions = RecordingFunctionsClient()
    let tokenProvider = MockTokenProvider(error: TestError())

    let provider = SupabaseClientProvider(
      environmentLoader: { SupabaseEnvironment(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key") },
      tokenProvider: tokenProvider,
      clientFactory: { _, _ in RecordingSupabaseClient(functionsClient: functions) }
    )

    do {
      _ = try await provider.clerkToken()
      XCTFail("Expected clerkToken to throw when token provider fails")
    } catch let error as TestError {
      XCTAssertTrue(error === tokenProvider.error)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

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

private final class MockTokenProvider: SupabaseTokenProviding {
  private let tokens: [String]
  private var index = 0
  let error: TestError?
  private(set) var requestedTokens: [String] = []

  init(tokens: [String]) {
    self.tokens = tokens
    self.error = nil
  }

  init(error: TestError) {
    self.tokens = []
    self.error = error
  }

  func currentToken() async throws -> String {
    if let error {
      throw error
    }

    guard index < tokens.count else {
      fatalError("No more tokens available for mock provider")
    }

    let token = tokens[index]
    index += 1
    requestedTokens.append(token)
    return token
  }
}

private final class TestError: Error {}
