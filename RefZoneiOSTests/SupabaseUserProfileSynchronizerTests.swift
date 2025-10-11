import Foundation
import Supabase
import XCTest
@testable import RefZoneiOS

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
    XCTAssertEqual(payload.emailConfirmedAt, ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z"))
    XCTAssertEqual(payload.isSSOUser, false)
    XCTAssertEqual(payload.isAnonymous, false)
    XCTAssertEqual(payload.lastSignInAt, ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z"))
    XCTAssertEqual(payload.createdAt, ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z"))
    XCTAssertEqual(payload.updatedAt, ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z"))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(payload)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let row = try XCTUnwrap(json.first)
    XCTAssertEqual(row["is_sso_user"] as? Bool, false)
    XCTAssertEqual(row["is_anonymous"] as? Bool, false)
    XCTAssertEqual(row["email_confirmed_at"] as? String, "2024-01-01T00:00:00Z")
    let rawUserMetadata = try XCTUnwrap(row["raw_user_metadata"] as? [String: Any])
    XCTAssertEqual(rawUserMetadata["full_name"] as? String, "Tester")
    XCTAssertEqual(rawUserMetadata["avatar_url"] as? String, "https://example.com/avatar.png")
    XCTAssertEqual(rawUserMetadata["email_verified"] as? Bool, true)
    XCTAssertEqual(rawUserMetadata["phone_verified"] as? Bool, false)
    let claims = try XCTUnwrap(rawUserMetadata["custom_claims"] as? [String: Any])
    XCTAssertEqual(claims["auth_time"] as? Int, 1_700_000_000)
    XCTAssertEqual(claims["beta"] as? Bool, true)

    let rawAppMetadata = try XCTUnwrap(row["raw_app_metadata"] as? [String: Any])
    XCTAssertEqual(rawAppMetadata["provider"] as? String, "google")
    XCTAssertEqual(rawAppMetadata["providers"] as? [String], ["email", "google"])
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

  func testAnyEncodable_whenWrappingAnyCodableMetadata_encodesJSONCorrectly() throws {
    let rawAppMetadata: [String: TestAnyCodable] = [
      "provider": TestAnyCodable("google"),
      "providers": TestAnyCodable(["Email", "GOOGLE", "email", "  google  "])
    ]

    let rawUserMetadata: [String: TestAnyCodable] = [
      "full_name": TestAnyCodable("Tester"),
      "avatar_url": TestAnyCodable("https://example.com/avatar.png"),
      "email_verified": TestAnyCodable(true),
      "phone_verified": TestAnyCodable(false),
      "custom_claims": TestAnyCodable(["auth_time": 1_700_000_000, "beta": true])
    ]

    let payload = SupabaseUserProfilePayload(
      id: UUID(uuidString: "22222222-2222-3333-4444-555555555555")!,
      email: "test@example.com",
      displayName: "Tester",
      avatarURL: nil,
      emailVerified: true,
      emailConfirmedAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z"),
      isSSOUser: false,
      isAnonymous: false,
      lastSignInAt: ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z"),
      rawAppMetadata: AnyEncodable(rawAppMetadata),
      rawUserMetadata: AnyEncodable(rawUserMetadata),
      createdAt: ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!,
      updatedAt: ISO8601DateFormatter().date(from: "2024-01-02T00:00:00Z")!
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode([payload])
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let row = try XCTUnwrap(json.first)

    XCTAssertEqual(row["email_verified"] as? Bool, true)
    XCTAssertEqual(row["is_anonymous"] as? Bool, false)

    let encodedAppMetadata = try XCTUnwrap(row["raw_app_metadata"] as? [String: Any])
    XCTAssertEqual(encodedAppMetadata["providers"] as? [String], ["email", "google"])

    let encodedUserMetadata = try XCTUnwrap(row["raw_user_metadata"] as? [String: Any])
    XCTAssertEqual(encodedUserMetadata["email_verified"] as? Bool, true)
    XCTAssertEqual(encodedUserMetadata["phone_verified"] as? Bool, false)
    let claims = try XCTUnwrap(encodedUserMetadata["custom_claims"] as? [String: Any])
    XCTAssertEqual(claims["auth_time"] as? Int, 1_700_000_000)
    XCTAssertEqual(claims["beta"] as? Bool, true)
  }
}

private struct TestAnyCodable {
  let value: Any

  init(_ value: Any) {
    self.value = value
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
        "provider": "google",
        "providers": [
          "Email",
          "GOOGLE",
          "email",
          "  google  ",
          "null",
          ""
        ]
      },
      "user_metadata": {
        "full_name": "Tester",
        "avatar_url": "https://example.com/avatar.png",
        "custom_claims": {
          "auth_time": 1700000000,
          "beta": true
        },
        "email_verified": true,
        "phone_verified": false
      },
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-02T00:00:00Z",
      "is_anonymous": false,
      "is_sso_user": false,
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

  func refreshFunctionAuth() async {}
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

  func invoke<Response>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decode: (Data, HTTPURLResponse) throws -> Response
  ) async throws -> Response {
    fatalError("Functions should not be invoked in synchronizer tests")
  }

  func invoke<T>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T where T : Decodable {
    fatalError("Functions should not be invoked in synchronizer tests")
  }
}
