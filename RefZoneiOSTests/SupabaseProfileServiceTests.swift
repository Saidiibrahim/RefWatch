import XCTest
@testable import RefZoneiOS
import Supabase

final class SupabaseProfileServiceTests: XCTestCase {
  func testFetchProfileReturnsParsedData() async throws {
    let uuid = UUID(uuidString: "A680F4C9-067B-4B73-9E7A-B19B083F49AE")!
    let isoFormatter = ISO8601DateFormatter()
    let payload: [[String: Any]] = [[
      "id": uuid.uuidString,
      "clerk_user_id": "clerk-1",
      "primary_email": "user@example.com",
      "display_name": "Alex",
      "status": "inactive",
      "last_active_at": "2025-09-24T12:00:00Z",
      "clerk_last_synced_at": "2025-09-24T12:05:00Z",
      "updated_at": "2025-09-24T12:10:00Z"
    ]]
    let data = try JSONSerialization.data(withJSONObject: payload)

    let client = RecordingSupabaseClient(data: data)
    let provider = MockClientProvider(client: client)
    let service = SupabaseProfileService(clientProvider: provider)

    let profile = try await service.fetchProfile(forClerkUserId: "clerk-1")

    XCTAssertEqual(client.recordedRequests.count, 1)
    let request = try XCTUnwrap(client.recordedRequests.first)
    XCTAssertEqual(request.table, "users")
    XCTAssertEqual(request.filters, [.equals("clerk_user_id", value: "clerk-1")])
    XCTAssertNil(request.orderBy)
    XCTAssertEqual(request.limit, 1)

    XCTAssertEqual(profile.supabaseUserId, uuid.uuidString)
    XCTAssertEqual(profile.clerkUserId, "clerk-1")
    XCTAssertEqual(profile.primaryEmail, "user@example.com")
    XCTAssertEqual(profile.status, .inactive)
    XCTAssertEqual(profile.lastActiveAt, isoFormatter.date(from: "2025-09-24T12:00:00Z"))
    XCTAssertEqual(profile.clerkLastSyncedAt, isoFormatter.date(from: "2025-09-24T12:05:00Z"))
    XCTAssertEqual(profile.updatedAt, isoFormatter.date(from: "2025-09-24T12:10:00Z"))
  }

  func testFetchProfileMapsPermissionErrors() async {
    let client = RecordingSupabaseClient(data: Data(), error: PermissionDeniedError())
    let provider = MockClientProvider(client: client)
    let service = SupabaseProfileService(clientProvider: provider)

    do {
      _ = try await service.fetchProfile(forClerkUserId: "clerk-1")
      XCTFail("Expected fetchProfile to throw access denied")
    } catch let error as SupabaseProfileServiceError {
      XCTAssertEqual(error, .accessDenied)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFetchProfileThrowsWhenNoRowsReturned() async {
    let empty = try JSONSerialization.data(withJSONObject: [])
    let client = RecordingSupabaseClient(data: empty)
    let provider = MockClientProvider(client: client)
    let service = SupabaseProfileService(clientProvider: provider)

    do {
      _ = try await service.fetchProfile(forClerkUserId: "clerk-1")
      XCTFail("Expected profileNotFound error")
    } catch let error as SupabaseProfileServiceError {
      XCTAssertEqual(error, .profileNotFound)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}

private final class RecordingSupabaseClient: SupabaseClientRepresenting {
  struct Request: Equatable {
    let table: String
    let columns: String
    let filters: [SupabaseQueryFilter]
    let orderBy: String?
    let ascending: Bool
    let limit: Int
  }

  private(set) var recordedRequests: [Request] = []
  let functionsClient: SupabaseFunctionsClientRepresenting = DummyFunctionsClient()
  private let data: Data
  private let error: Error?

  init(data: Data, error: Error? = nil) {
    self.data = data
    self.error = error
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
    recordedRequests.append(Request(table: table, columns: columns, filters: filters, orderBy: column, ascending: ascending, limit: limit))

    if let error {
      throw error
    }

    return try decoder.decode([T].self, from: data)
  }

  func callRPC<Params, Response>(
    _ function: String,
    params: Params,
    encoder: JSONEncoder,
    decoder: JSONDecoder
  ) async throws -> Response where Params : Encodable, Response : Decodable {
    fatalError("RPC should not be invoked in profile service tests")
  }
}

private final class DummyFunctionsClient: SupabaseFunctionsClientRepresenting {
  private(set) var tokens: [String?] = []

  func setAuth(token: String?) {
    tokens.append(token)
  }

  func invoke<T>(
    _ functionName: String,
    options: FunctionInvokeOptions,
    decoder: JSONDecoder
  ) async throws -> T where T : Decodable {
    fatalError("Functions client should not be invoked in profile service tests")
  }
}

private final class MockClientProvider: SupabaseClientProviding {
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

  func clerkToken() async throws -> String {
    ""
  }
}

private struct PermissionDeniedError: LocalizedError {
  var errorDescription: String? {
    "permission denied for table"
  }
}
