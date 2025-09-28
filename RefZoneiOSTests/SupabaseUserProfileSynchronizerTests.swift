import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseUserProfileSynchronizerTests: XCTestCase {
  func testSyncIfNeeded_whenSessionIsNil_doesNotInvokeUpsert() async throws {
    let client = RecordingSupabaseClient()
    let provider = RecordingSupabaseClientProvider(client: client)
    let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: provider, now: { Date(timeIntervalSince1970: 1_700_000_000) })

    try await synchronizer.syncIfNeeded(session: nil)

    XCTAssertNil(client.lastUpsertTable)
  }

  func testSyncIfNeeded_whenSessionPresent_upsertsExpectedPayload() async throws {
    let session = try makeSession()
    let client = RecordingSupabaseClient()
    let provider = RecordingSupabaseClientProvider(client: client)
    let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: provider, now: { Date(timeIntervalSince1970: 1_700_000_123) })

    try await synchronizer.syncIfNeeded(session: session)

    XCTAssertEqual(client.lastUpsertTable, "users")
    XCTAssertEqual(client.lastOnConflict, "id")
    let payload = try XCTUnwrap(client.lastPayload?.first)
    XCTAssertEqual(payload.id, session.user.id)
    XCTAssertEqual(payload.email, "test@example.com")
    XCTAssertEqual(payload.displayName, "Tester")
    XCTAssertEqual(payload.avatarURL, "https://example.com/avatar.png")
    XCTAssertTrue(payload.emailVerified)
    XCTAssertEqual(payload.lastSignInAt, ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z"))
    XCTAssertEqual(payload.createdAt, ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z"))
    XCTAssertEqual(payload.updatedAt, ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z"))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(payload)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let row = try XCTUnwrap(json.first)
    let rawUserMetadata = try XCTUnwrap(row["raw_user_metadata"] as? [String: Any])
    XCTAssertEqual(rawUserMetadata["full_name"] as? String, "Tester")
    XCTAssertEqual(rawUserMetadata["avatar_url"] as? String, "https://example.com/avatar.png")

    let rawAppMetadata = try XCTUnwrap(row["raw_app_metadata"] as? [String: Any])
    XCTAssertEqual(rawAppMetadata["provider"] as? String, "email")
  }

  func testSyncIfNeeded_whenUpsertFails_throws() async throws {
    let session = try makeSession()
    let client = RecordingSupabaseClient()
    client.error = TestError()
    let provider = RecordingSupabaseClientProvider(client: client)
    let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: provider)

    await XCTAssertThrowsError(try await synchronizer.syncIfNeeded(session: session)) { error in
      XCTAssertTrue(error is TestError)
    }
  }
}

private func makeSession() throws -> Session {
  let json = """
  {
    "access_token": "access-token",
    "token_type": "bearer",
    "expires_in": 3600,
    "expires_at": 1700000300,
    "refresh_token": "refresh-token",
    "provider_token": null,
    "provider_refresh_token": null,
    "user": {
      "id": "11111111-2222-3333-4444-555555555555",
      "aud": "authenticated",
      "role": "authenticated",
      "email": "test@example.com",
      "email_confirmed_at": "2024-01-01T00:00:00Z",
      "last_sign_in_at": "2024-01-02T00:00:00Z",
      "app_metadata": {
        "provider": "email"
      },
      "user_metadata": {
        "full_name": "Tester",
        "avatar_url": "https://example.com/avatar.png"
      },
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-02T00:00:00Z",
      "is_anonymous": false,
      "identities": []
    }
  }
  """
  let data = Data(json.utf8)
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return try decoder.decode(Session.self, from: data)
}

private struct TestError: Error {}

private final class RecordingSupabaseClientProvider: SupabaseClientProviding {
  private let client: SupabaseClientRepresenting

  init(client: SupabaseClientRepresenting) {
    self.client = client
  }

  func client() throws -> SupabaseClientRepresenting {
    client
  }

  func authorizedClient() async throws -> SupabaseClientRepresenting {
    client
  }

  func refreshFunctionAuth() {}
}

private final class RecordingSupabaseClient: SupabaseClientRepresenting {
  let functionsClient: SupabaseFunctionsClientRepresenting = NoopFunctionsClient()

  var lastUpsertTable: String?
  var lastOnConflict: String?
  var lastPayload: [SupabaseUserProfilePayload]?
  var error: Error?

  func fetchRows<T>(
    from table: String,
    select columns: String,
    filters: [SupabaseQueryFilter],
    orderBy column: String?,
    ascending: Bool,
    limit: Int,
    decoder: JSONDecoder
  ) async throws -> [T] where T : Decodable {
    return []
  }

  func callRPC<Params, Response>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response where Params : Encodable, Response : Decodable {
    fatalError("RPC should not be called in synchronizer tests")
  }

  func upsertRows<Payload, Response>(
    into table: String,
    payload: Payload,
    onConflict: String,
    decoder: JSONDecoder
  ) async throws -> Response where Payload : Encodable, Response : Decodable {
    lastUpsertTable = table
    lastOnConflict = onConflict
    guard let typedPayload = payload as? [SupabaseUserProfilePayload] else {
      fatalError("Unexpected payload type \(Payload.self)")
    }
    lastPayload = typedPayload
    if let error {
      throw error
    }
    guard let response = [SupabaseUserProfileRow(id: typedPayload[0].id)] as? Response else {
      fatalError("Unexpected response type \(Response.self)")
    }
    return response
  }
}

private final class NoopFunctionsClient: SupabaseFunctionsClientRepresenting {
  func setAuth(token: String?) {}

  func invoke<T>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T where T : Decodable {
    fatalError("Functions should not be invoked in synchronizer tests")
  }
}
