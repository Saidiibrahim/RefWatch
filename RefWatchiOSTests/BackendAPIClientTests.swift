import XCTest
@testable import RefWatchiOS

@MainActor
final class BackendAPIClientTests: XCTestCase {
  func testSend_whenAuthenticated_attachesBearerTokenAndDecodesResponse() async throws {
    let transport = BackendTransportSpy(
      status: 200,
      body: #"{"appUserId":"67d622c8-9976-4e8c-b47b-1883495e21a9","clerkUserId":"user_clerk-not-a-uuid","email":"ref@example.com","displayName":"Ref"}"#.data(using: .utf8)!)
    let client = BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: SessionTokenStub(token: "clerk-session-token"),
      transport: transport)

    let identity: AuthenticatedIdentity = try await client.send(path: "/api/me")

    XCTAssertEqual(identity.clerkUserId, "user_clerk-not-a-uuid")
    let recordedRequest = transport.lastRequest
    let request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer clerk-session-token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }

  func testSend_whenBackendReturns401_surfacesUnauthenticated() async {
    let transport = BackendTransportSpy(
      status: 401,
      body: #"{"message":"Session expired"}"#.data(using: .utf8)!)
    let client = makeClient(transport: transport)

    do {
      let _: AuthenticatedIdentity = try await client.send(path: "/api/me")
      XCTFail("Expected request to fail")
    } catch {
      XCTAssertEqual(error as? BackendAPIError, .unauthenticated(message: "Session expired"))
    }
  }

  func testSend_whenBackendReturns403_surfacesForbidden() async {
    let transport = BackendTransportSpy(status: 403, body: Data())
    let client = makeClient(transport: transport)

    do {
      let _: AuthenticatedIdentity = try await client.send(path: "/api/me")
      XCTFail("Expected request to fail")
    } catch {
      XCTAssertEqual(error as? BackendAPIError, .forbidden(message: nil))
    }
  }

  func testSend_whenBackendReturns422_preservesValidationBody() async {
    let body = #"{"message":"match_id is invalid","field":"match_id"}"#.data(using: .utf8)!
    let transport = BackendTransportSpy(status: 422, body: body)
    let client = makeClient(transport: transport)

    do {
      let _: AuthenticatedIdentity = try await client.send(path: "/api/me")
      XCTFail("Expected request to fail")
    } catch {
      XCTAssertEqual(
        error as? BackendAPIError,
        .validation(message: "match_id is invalid", details: body))
    }
  }

  func testSend_whenBackendReturns500_surfacesServerError() async {
    let transport = BackendTransportSpy(status: 500, body: Data())
    let client = makeClient(transport: transport)

    do {
      let _: AuthenticatedIdentity = try await client.send(path: "/api/me")
      XCTFail("Expected request to fail")
    } catch {
      XCTAssertEqual(error as? BackendAPIError, .server(status: 500, message: nil))
    }
  }

  func testIdentityProvider_whenClerkAccountChanges_doesNotReusePreviousIdentity() async throws {
    let first = #"{"appUserId":"67d622c8-9976-4e8c-b47b-1883495e21a9","clerkUserId":"user_a","email":null,"displayName":null}"#.data(using: .utf8)!
    let second = #"{"appUserId":"36fdd44e-f96e-48d4-ab20-bc12aec3d4f8","clerkUserId":"user_b","email":null,"displayName":null}"#.data(using: .utf8)!
    let transport = BackendSequenceTransport(bodies: [first, first, second])
    let client = BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: SessionTokenStub(token: "token"),
      transport: transport)
    let provider = BackendIdentityProvider(client: client)

    let firstIdentity = try await provider.authenticatedIdentity(forClerkUserId: "user_a", forceRefresh: false)
    let cachedFirstIdentity = try await provider.authenticatedIdentity(forClerkUserId: "user_a", forceRefresh: false)
    let secondIdentity = try await provider.authenticatedIdentity(forClerkUserId: "user_b", forceRefresh: false)

    XCTAssertEqual(firstIdentity.clerkUserId, "user_a")
    XCTAssertEqual(cachedFirstIdentity, firstIdentity)
    XCTAssertEqual(secondIdentity.clerkUserId, "user_b")
    XCTAssertEqual(transport.requestCount, 3)
  }

  func testIdentityProvider_whenOffline_usesPersistedMappingForSameClerkSubject() async throws {
    let suiteName = "BackendIdentityProviderTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let identityBody = #"{"appUserId":"67d622c8-9976-4e8c-b47b-1883495e21a9","clerkUserId":"user_a","email":null,"displayName":null}"#.data(using: .utf8)!
    let onlineClient = BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: SessionTokenStub(token: "token"),
      transport: BackendTransportSpy(status: 200, body: identityBody))
    let onlineProvider = BackendIdentityProvider(client: onlineClient, defaults: defaults)
    let expected = try await onlineProvider.authenticatedIdentity(
      forClerkUserId: "user_a",
      forceRefresh: false)

    let offlineClient = BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: SessionTokenStub(token: "token"),
      transport: FailingBackendTransport())
    let restoredProvider = BackendIdentityProvider(client: offlineClient, defaults: defaults)
    let restored = try await restoredProvider.authenticatedIdentity(
      forClerkUserId: "user_a",
      forceRefresh: false)

    XCTAssertEqual(restored, expected)
  }

  func testIdentityProvider_whenTokenUnavailableOffline_usesPersistedMappingForSameClerkSubject() async throws {
    let suiteName = "BackendIdentityProviderTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let expected = AuthenticatedIdentity(
      clerkUserId: "user_a",
      appUserId: "67d622c8-9976-4e8c-b47b-1883495e21a9",
      email: nil,
      displayName: nil)
    defaults.set(try JSONEncoder().encode(expected), forKey: "RefWatch.backendIdentity.v1")
    let client = BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: FailingSessionTokenStub(),
      transport: FailingBackendTransport())

    let restored = try await BackendIdentityProvider(client: client, defaults: defaults)
      .authenticatedIdentity(forClerkUserId: "user_a", forceRefresh: false)

    XCTAssertEqual(restored, expected)
  }

  func testIdentityProvider_whenInvalidated_removesPersistedMapping() async throws {
    let suiteName = "BackendIdentityProviderTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let identityBody = #"{"appUserId":"67d622c8-9976-4e8c-b47b-1883495e21a9","clerkUserId":"user_a","email":null,"displayName":null}"#.data(using: .utf8)!
    let provider = BackendIdentityProvider(
      client: BackendAPIClient(
        baseURL: URL(string: "https://api.refwatch.test")!,
        tokenProvider: SessionTokenStub(token: "token"),
        transport: BackendTransportSpy(status: 200, body: identityBody)),
      defaults: defaults)
    _ = try await provider.authenticatedIdentity(forClerkUserId: "user_a", forceRefresh: false)

    await provider.invalidateCachedIdentity(forClerkUserId: "user_a")

    XCTAssertNil(defaults.data(forKey: "RefWatch.backendIdentity.v1"))
  }

  func testReferenceCatalogTeams_usesAuthenticatedBackendContract() async throws {
    let body = #"[{"id":"5b111111-1111-4111-8111-111111111111","reference_key":"sa-kaizer-chiefs","name":"Kaizer Chiefs","short_name":"CHI","competition_code":"PSL","competition_name":"Premier Soccer League","season_year":2026}]"#.data(using: .utf8)!
    let transport = BackendTransportSpy(status: 200, body: body)
    let client = makeClient(transport: transport)

    let teams = try await BackendReferenceCatalogService(client: client)
      .fetchReferenceTeams(seasonYear: 2026)

    XCTAssertEqual(teams.count, 1)
    XCTAssertEqual(teams.first?.referenceKey, "sa-kaizer-chiefs")
    XCTAssertEqual(teams.first?.competitionCode, "PSL")
    let recordedRequest = transport.lastRequest
    let request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(request.url?.path, "/api/reference-catalog/teams")
    XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems,
                   [URLQueryItem(name: "seasonYear", value: "2026")])
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
  }

  func testReferenceCatalogCompetitions_decodesBackendContract() async throws {
    let body = #"[{"id":"4a111111-1111-4111-8111-111111111111","code":"PSL","name":"Premier Soccer League","season_year":2026}]"#.data(using: .utf8)!
    let transport = BackendTransportSpy(status: 200, body: body)

    let competitions = try await BackendReferenceCatalogService(client: makeClient(transport: transport))
      .fetchReferenceCompetitions(seasonYear: 2026)

    XCTAssertEqual(
      competitions,
      [ReferenceCompetitionOption(
        id: UUID(uuidString: "4a111111-1111-4111-8111-111111111111")!,
        code: "PSL",
        name: "Premier Soccer League")])
  }

  private func makeClient(transport: BackendTransportSpy) -> BackendAPIClient {
    BackendAPIClient(
      baseURL: URL(string: "https://api.refwatch.test")!,
      tokenProvider: SessionTokenStub(token: "token"),
      transport: transport)
  }
}

@MainActor
private final class BackendSequenceTransport: BackendHTTPTransport {
  private let bodies: [Data]
  private(set) var requestCount = 0

  init(bodies: [Data]) {
    self.bodies = bodies
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let index = min(requestCount, bodies.count - 1)
    requestCount += 1
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil)!
    return (bodies[index], response)
  }

  func stream(for request: URLRequest) async throws -> BackendHTTPStream {
    throw BackendAPIError.transport(message: "Streaming is not used by this test.")
  }
}

@MainActor
private final class FailingBackendTransport: BackendHTTPTransport {
  func data(for _: URLRequest) async throws -> (Data, URLResponse) {
    throw URLError(.notConnectedToInternet)
  }

  func stream(for _: URLRequest) async throws -> BackendHTTPStream {
    throw URLError(.notConnectedToInternet)
  }
}

@MainActor
private struct SessionTokenStub: SessionTokenProviding {
  let token: String

  func sessionToken() async throws -> String { token }
}

@MainActor
private struct FailingSessionTokenStub: SessionTokenProviding {
  struct TokenUnavailable: Error {}

  func sessionToken() async throws -> String { throw TokenUnavailable() }
}

@MainActor
private final class BackendTransportSpy: BackendHTTPTransport {
  let status: Int
  let body: Data
  private(set) var lastRequest: URLRequest?

  init(status: Int, body: Data) {
    self.status = status
    self.body = body
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    lastRequest = request
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: nil,
      headerFields: nil)!
    return (body, response)
  }

  func stream(for request: URLRequest) async throws -> BackendHTTPStream {
    throw BackendAPIError.transport(message: "Streaming is not used by this test.")
  }
}
