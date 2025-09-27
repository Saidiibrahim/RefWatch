import XCTest
import SwiftData
import Combine
@testable import RefZoneiOS
@testable import RefWatchCore

@MainActor
final class SupabaseMatchHistoryRepositoryTests: XCTestCase {
  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([CompletedMatchRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  func testSaveQueuesPushAndClearsDirtyOnSuccess() async throws {
    let container = try makeContainer()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: NoopAuth(), importJSONOnFirstRun: false)
    let authProvider = StubAuthProvider()
    let api = MockMatchIngestService()
    let backlog = StubMatchBacklogStore()
    let repository = SupabaseMatchHistoryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      deviceIdProvider: { "DEVICE" }
    )

    let ownerId = UUID()
    authProvider.markSignedIn(userId: ownerId.uuidString, email: "owner@example.com")

    let expectation = expectation(description: "ingest")
    api.ingestExpectation = expectation

    try repository.save(makeCompletedMatch())

    await fulfillment(of: [expectation], timeout: 2.0)
    try? await Task.sleep(nanoseconds: 200_000_000)

    guard let record = try baseStore.fetchRecord(id: api.ingestRequests.first?.match.id ?? UUID()) else {
      XCTFail("Record not saved")
      return
    }

    XCTAssertFalse(record.needsRemoteSync)
    XCTAssertEqual(record.ownerId, ownerId.uuidString)
    XCTAssertNotNil(record.remoteUpdatedAt)
    XCTAssertEqual(record.sourceDeviceId, "DEVICE")
    XCTAssertTrue(backlog.pendingIDs.isEmpty)
  }

  func testDeleteQueuesBacklogWhenAPIFails() async throws {
    let container = try makeContainer()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: NoopAuth(), importJSONOnFirstRun: false)
    let authProvider = StubAuthProvider()
    let api = MockMatchIngestService()
    api.deleteError = TestError()
    let backlog = StubMatchBacklogStore()
    let repository = SupabaseMatchHistoryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    authProvider.markSignedIn(userId: UUID().uuidString)

    try repository.save(makeCompletedMatch())
    try? await Task.sleep(nanoseconds: 400_000_000)

    guard let matchId = baseStore.loadAll().first?.id else {
      XCTFail("Missing saved match")
      return
    }

    try repository.delete(id: matchId)
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(api.deleteRequests.count, 1)
    XCTAssertEqual(backlog.pendingIDs, [matchId])
    XCTAssertTrue((try? baseStore.loadAll().isEmpty) ?? false)
  }

  func testPullRemoteInsertsMatch() async throws {
    let container = try makeContainer()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: NoopAuth(), importJSONOnFirstRun: false)
    let authProvider = StubAuthProvider()
    let api = MockMatchIngestService()
    let backlog = StubMatchBacklogStore()

    let remoteId = UUID()
    let ownerId = UUID()
    let now = Date()
    api.fetchResult = [
      SupabaseMatchIngestService.RemoteMatchBundle(
        match: SupabaseMatchIngestService.RemoteMatch(
          id: remoteId,
          ownerId: ownerId,
          status: "completed",
          startedAt: now,
          completedAt: now,
          durationSeconds: 5400,
          numberOfPeriods: 2,
          regulationMinutes: 90,
          halfTimeMinutes: 15,
          competitionId: nil,
          competitionName: nil,
          venueId: nil,
          venueName: nil,
          homeTeamId: nil,
          homeTeamName: "Remote FC",
          awayTeamId: nil,
          awayTeamName: "Visitors",
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
            awayYellowCards: 0,
            homeRedCards: 0,
            awayRedCards: 0,
            homeSubstitutions: 2,
            awaySubstitutions: 1
          ),
          sourceDeviceId: "remote",
          updatedAt: now
        ),
        periods: [],
        events: []
      )
    ]

    let repository = SupabaseMatchHistoryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    let expectation = expectation(description: "fetch")
    api.fetchExpectation = expectation

    authProvider.markSignedIn(userId: ownerId.uuidString)

    await fulfillment(of: [expectation], timeout: 2.0)
    try? await Task.sleep(nanoseconds: 300_000_000)

    let matches = try baseStore.loadAll()
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches.first?.id, remoteId)
    let record = try XCTUnwrap(baseStore.fetchRecord(id: remoteId))
    XCTAssertFalse(record.needsRemoteSync)
    XCTAssertEqual(record.homeTeam, "Remote FC")
  }
}

// MARK: - Test Doubles

@MainActor
private final class StubAuthProvider: SupabaseAuthStateProviding {
  private let subject = CurrentValueSubject<AuthState, Never>(.signedOut)

  var state: AuthState { subject.value }

  var currentUserId: String? {
    if case let .signedIn(userId, _, _) = subject.value { return userId }
    return nil
  }

  var currentEmail: String? {
    if case let .signedIn(_, email, _) = subject.value { return email }
    return nil
  }

  var currentDisplayName: String? {
    if case let .signedIn(_, _, name) = subject.value { return name }
    return nil
  }

  var statePublisher: AnyPublisher<AuthState, Never> {
    subject.eraseToAnyPublisher()
  }

  func markSignedIn(userId: String, email: String? = nil) {
    subject.send(.signedIn(userId: userId, email: email, displayName: nil))
  }

  func markSignedOut() {
    subject.send(.signedOut)
  }
}

private final class StubMatchBacklogStore: MatchSyncBacklogStoring {
  private(set) var pendingIDs: [UUID] = []

  func loadPendingDeletionIDs() -> Set<UUID> { Set(pendingIDs) }

  func addPendingDeletion(id: UUID) { if !pendingIDs.contains(id) { pendingIDs.append(id) } }

  func removePendingDeletion(id: UUID) { pendingIDs.removeAll { $0 == id } }
}

private final class MockMatchIngestService: SupabaseMatchIngestServing {
  var ingestRequests: [SupabaseMatchIngestService.MatchBundleRequest] = []
  var ingestExpectation: XCTestExpectation?
  var deleteRequests: [UUID] = []
  var deleteError: Error?
  var fetchResult: [SupabaseMatchIngestService.RemoteMatchBundle] = []
  var fetchExpectation: XCTestExpectation?

  func ingestMatchBundle(_ request: SupabaseMatchIngestService.MatchBundleRequest) async throws -> SupabaseMatchIngestService.SyncResult {
    ingestRequests.append(request)
    ingestExpectation?.fulfill()
    return SupabaseMatchIngestService.SyncResult(matchId: request.match.id, updatedAt: Date())
  }

  func fetchMatchBundles(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseMatchIngestService.RemoteMatchBundle] {
    fetchExpectation?.fulfill()
    return fetchResult
  }

  func deleteMatch(id: UUID) async throws {
    deleteRequests.append(id)
    if let deleteError { throw deleteError }
  }
}

private struct TestError: Error {}

private func makeCompletedMatch() -> CompletedMatch {
  let match = Match(homeTeam: "Home", awayTeam: "Away")
  return CompletedMatch(match: match, events: [])
}
