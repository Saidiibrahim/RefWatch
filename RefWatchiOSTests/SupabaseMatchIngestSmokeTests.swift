import Foundation
import RefWatchCore
@testable import RefWatchiOS
import Supabase
import XCTest

final class SupabaseMatchIngestSmokeTests: XCTestCase {
  func test_ingest_and_fetch_round_trip() async throws {
    let environment = try TestEnvironment.load()

    let provider = SupabaseClientProvider(
      environmentLoader: {
        SupabaseEnvironment(url: environment.supabase.url, anonKey: environment.supabase.anonKey)
      },
      clientFactory: { env in
        SupabaseClient(
          supabaseURL: env.url,
          supabaseKey: env.anonKey,
          options: SupabaseClientOptions()
        )
      }
    )

    guard let client = try provider.client() as? SupabaseClient else {
      XCTFail("SupabaseClientProvider.client did not return SupabaseClient instance")
      return
    }

    let admin = SupabaseAdminClient(baseURL: environment.supabase.url, serviceRoleKey: environment.serviceRoleKey)
    let testAccount = try await admin.createUser()

    let session = try await client.auth.signIn(email: testAccount.email, password: testAccount.password)
    XCTAssertEqual(session.user.id.uuidString.lowercased(), testAccount.id.lowercased())

    await provider.refreshFunctionAuth()
    _ = try await provider.authorizedClient()

    let ingestService = SupabaseMatchIngestService(clientProvider: provider)

    guard let ownerUUID = UUID(uuidString: testAccount.id) else {
      XCTFail("Invalid Supabase user id returned: \(testAccount.id)")
      return
    }
    let matchId = UUID()
    let request = makeBundleRequest(matchId: matchId, ownerId: ownerUUID)

    let syncResult = try await ingestService.ingestMatchBundle(request)
    XCTAssertEqual(syncResult.matchId, matchId)

    let fetched = try await ingestService.fetchMatchBundles(ownerId: ownerUUID, updatedAfter: nil)
    guard let bundle = fetched.first(where: { $0.match.id == matchId }) else {
      XCTFail("Expected ingested match to be returned from fetch")
      return
    }

    XCTAssertEqual(bundle.match.homeTeamName, request.match.homeTeamName)
    XCTAssertEqual(bundle.match.awayTeamName, request.match.awayTeamName)
    XCTAssertEqual(bundle.events.count, request.events.count)

    try await ingestService.deleteMatch(id: matchId)
    try await admin.deleteUser(id: testAccount.id)
  }
}

private extension SupabaseMatchIngestSmokeTests {
  struct TestEnvironment {
    struct SupabaseConfig {
      let url: URL
      let anonKey: String
    }

    let supabase: SupabaseConfig
    let serviceRoleKey: String

    static func load(file: StaticString = #file, line: UInt = #line) throws -> TestEnvironment {
      let process = ProcessInfo.processInfo.environment

      guard let urlString = process["SUPABASE_URL"], let url = URL(string: urlString) else {
        throw XCTSkip("SUPABASE_URL not configured; set test environment variables to run smoke test.")
      }
      guard let anonKey = process["SUPABASE_ANON_KEY"], anonKey.isEmpty == false else {
        throw XCTSkip("SUPABASE_ANON_KEY not configured; set test environment variables to run smoke test.")
      }
      guard let serviceRoleKey = process["SUPABASE_SERVICE_ROLE_KEY"], serviceRoleKey.isEmpty == false else {
        throw XCTSkip("SUPABASE_SERVICE_ROLE_KEY not configured; set test environment variables to run smoke test.")
      }

      return TestEnvironment(
        supabase: SupabaseConfig(url: url, anonKey: anonKey),
        serviceRoleKey: serviceRoleKey
      )
    }
  }

  struct SupabaseAdminClient {
    struct CreatedUser {
      let id: String
      let email: String
      let password: String
    }

    enum AdminError: Error {
      case unexpectedStatus(Int, String)
      case decodingFailed
    }

    private let baseURL: URL
    private let serviceRoleKey: String
    private let session: URLSession

    init(baseURL: URL, serviceRoleKey: String, session: URLSession = .shared) {
      self.baseURL = baseURL
      self.serviceRoleKey = serviceRoleKey
      self.session = session
    }

    func createUser() async throws -> CreatedUser {
      let email = "matches-smoke-\(UUID().uuidString)@example.com"
      let password = "SmokeTest!\(Int.random(in: 1000...9999))"
      let payload = [
        "email": email,
        "password": password,
        "email_confirm": true
      ] as [String: Any]

      let requestURL = baseURL
        .appendingPathComponent("auth")
        .appendingPathComponent("v1")
        .appendingPathComponent("admin")
        .appendingPathComponent("users")

      var request = URLRequest(url: requestURL)
      request.httpMethod = "POST"
      request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(serviceRoleKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")

      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        throw AdminError.decodingFailed
      }
      guard (200..<300).contains(http.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? "<no body>"
        throw AdminError.unexpectedStatus(http.statusCode, body)
      }

      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      struct AdminUserResponse: Decodable { let id: String }
      guard let user = try? decoder.decode(AdminUserResponse.self, from: data) else {
        throw AdminError.decodingFailed
      }

      return CreatedUser(id: user.id, email: email, password: password)
    }

    func deleteUser(id: String) async throws {
      let requestURL = baseURL
        .appendingPathComponent("auth")
        .appendingPathComponent("v1")
        .appendingPathComponent("admin")
        .appendingPathComponent("users")
        .appendingPathComponent(id)

      var request = URLRequest(url: requestURL)
      request.httpMethod = "DELETE"
      request.setValue(serviceRoleKey, forHTTPHeaderField: "apikey")
      request.setValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")

      let (_, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else { return }
      guard (200..<300).contains(http.statusCode) else {
        throw AdminError.unexpectedStatus(http.statusCode, "delete user failed")
      }
    }
  }

  func makeBundleRequest(matchId: UUID, ownerId: UUID) -> SupabaseMatchIngestService.MatchBundleRequest {
    let now = Date()
    let match = SupabaseMatchIngestService.MatchBundleRequest.MatchPayload(
      id: matchId,
      ownerId: ownerId,
      status: "completed",
      scheduledMatchId: nil,
      startedAt: now.addingTimeInterval(-3600),
      completedAt: now,
      durationSeconds: 3600,
      numberOfPeriods: 2,
      regulationMinutes: 90,
      halfTimeMinutes: 15,
      competitionId: nil,
      competitionName: "Smoke League",
      venueId: nil,
      venueName: "Test Arena",
      homeTeamId: nil,
      homeTeamName: "Smoke United",
      awayTeamId: nil,
      awayTeamName: "Sample City",
      extraTimeEnabled: false,
      extraTimeHalfMinutes: nil,
      penaltiesEnabled: false,
      penaltyInitialRounds: 5,
      homeScore: 2,
      awayScore: 1,
      finalScore: SupabaseMatchIngestService.MatchBundleRequest.FinalScorePayload(
        home: 2,
        away: 1,
        homeYellowCards: 1,
        awayYellowCards: 2,
        homeRedCards: 0,
        awayRedCards: 0,
        homeSubstitutions: 3,
        awaySubstitutions: 2
      ),
      sourceDeviceId: "smoke-ios"
    )

    let period = SupabaseMatchIngestService.MatchBundleRequest.PeriodPayload(
      id: UUID(),
      matchId: matchId,
      index: 1,
      regulationSeconds: 2700,
      addedTimeSeconds: 60,
      result: SupabaseMatchIngestService.MatchBundleRequest.PeriodResultPayload(
        homeScore: 1,
        awayScore: 0
      )
    )

    let eventRecord = MatchEventRecord(
      id: UUID(),
      timestamp: now.addingTimeInterval(-1200),
      actualTime: now.addingTimeInterval(-1200),
      matchTime: "20:00",
      period: 1,
      eventType: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Tests")),
      team: .home,
      details: .goal(.init(goalType: .regular, playerNumber: 9, playerName: "Tests"))
    )

    let event = SupabaseMatchIngestService.MatchBundleRequest.EventPayload(
      id: eventRecord.id,
      matchId: matchId,
      occurredAt: eventRecord.actualTime,
      periodIndex: eventRecord.period,
      clockSeconds: 1200,
      matchTimeLabel: eventRecord.matchTime,
      eventType: "goal",
      payload: eventRecord,
      teamSide: "home"
    )

    let metrics = SupabaseMatchIngestService.MatchBundleRequest.MetricsPayload(
      matchId: matchId,
      ownerId: ownerId,
      regulationMinutes: 90,
      halfTimeMinutes: 15,
      extraTimeMinutes: nil,
      penaltiesEnabled: false,
      totalGoals: 3,
      totalCards: 3,
      totalPenalties: 0,
      yellowCards: 3,
      redCards: 0,
      homeCards: 1,
      awayCards: 2,
      homeSubstitutions: 3,
      awaySubstitutions: 2,
      penaltiesScored: 0,
      penaltiesMissed: 0,
      avgAddedTimeSeconds: 60
    )

    return SupabaseMatchIngestService.MatchBundleRequest(
      match: match,
      periods: [period],
      events: [event],
      metrics: metrics
    )
  }
}
