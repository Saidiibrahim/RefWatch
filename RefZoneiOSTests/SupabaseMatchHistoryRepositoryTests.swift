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
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
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

  func testMakeMatchBundleIncludesTeamIdentifiers() async throws {
    let container = try makeContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
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

    let homeId = UUID()
    let awayId = UUID()

    let expectation = expectation(description: "ingest")
    api.ingestExpectation = expectation

    try repository.save(makeCompletedMatch(homeTeamId: homeId, awayTeamId: awayId))

    await fulfillment(of: [expectation], timeout: 2.0)
    try? await Task.sleep(nanoseconds: 200_000_000)

    guard let request = api.ingestRequests.last else {
      XCTFail("Expected ingest request")
      return
    }

    XCTAssertEqual(request.match.homeTeamId, homeId)
    XCTAssertEqual(request.match.awayTeamId, awayId)
  }

  func testSaveWhileSignedOut_throwsAuthError() async throws {
    let container = try makeContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
    let api = MockMatchIngestService()
    let backlog = StubMatchBacklogStore()
    let repository = SupabaseMatchHistoryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      deviceIdProvider: { "DEVICE" }
    )

    let match = makeCompletedMatch()
    XCTAssertThrowsError(try repository.save(match)) { error in
      guard case PersistenceAuthError.signedOut = error else {
        XCTFail("Expected signed-out persistence error, got: \(error)")
        return
      }
    }

    XCTAssertTrue((try? baseStore.loadAll().isEmpty) ?? false)
    XCTAssertTrue(api.ingestRequests.isEmpty)
    XCTAssertTrue(backlog.pendingIDs.isEmpty)
  }

  func testHandleAuthState_whenSignedOut_wipesLocalCaches() async throws {
    let container = try makeContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
    let api = MockMatchIngestService()
    let backlog = StubMatchBacklogStore()
    let repository = SupabaseMatchHistoryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      deviceIdProvider: { "DEVICE" }
    )

    let ownerId = UUID().uuidString
    authProvider.markSignedIn(userId: ownerId, email: "owner@example.com")
    try await Task.sleep(nanoseconds: 200_000_000)

    try repository.save(makeCompletedMatch())
    XCTAssertEqual(try baseStore.loadAll().count, 1)

    let queuedId = UUID()
    backlog.addPendingDeletion(id: queuedId)
    backlog.updatePendingPushMetadata(
      MatchSyncPushMetadata(retryCount: 2, nextAttempt: Date().addingTimeInterval(30)),
      for: queuedId
    )

    authProvider.markSignedOut()
    try await Task.sleep(nanoseconds: 200_000_000)

    XCTAssertTrue((try? baseStore.loadAll().isEmpty) ?? false)
    XCTAssertTrue(backlog.pendingIDs.isEmpty)
    XCTAssertTrue(backlog.pushMetadata.isEmpty)
    XCTAssertEqual(backlog.clearAllCallCount, 1)
  }

  func testMatchMetricsPayloadIncludesAggregates() async throws {
    let container = try makeContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
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
    authProvider.markSignedIn(userId: ownerId.uuidString)

    var match = Match(homeTeam: "Home", awayTeam: "Away")
    match.startTime = Date()
    match.hasPenalties = true
    match.homeScore = 3
    match.awayScore = 2
    match.homeYellowCards = 2
    match.awayYellowCards = 1
    match.homeRedCards = 0
    match.awayRedCards = 1
    match.homeSubs = 3
    match.awaySubs = 2

    let goalDetails = GoalDetails(goalType: .regular, playerNumber: 9, playerName: "Striker")
    let goalEvent = MatchEventRecord(
      matchTime: "10:00",
      period: 1,
      eventType: .goal(goalDetails),
      team: .home,
      details: .goal(goalDetails)
    )

    let subDetails = SubstitutionDetails(playerOut: nil, playerIn: nil, playerOutName: nil, playerInName: nil)
    let substitutionEvent = MatchEventRecord(
      matchTime: "50:00",
      period: 1,
      eventType: .substitution(subDetails),
      team: .home,
      details: .substitution(subDetails)
    )

    let cardDetails = CardDetails(cardType: .red, recipientType: .player, playerNumber: nil, playerName: nil, officialRole: nil, reason: "")
    let cardEvent = MatchEventRecord(
      matchTime: "60:00",
      period: 2,
      eventType: .card(cardDetails),
      team: .away,
      details: .card(cardDetails)
    )

    let penaltyDetails = PenaltyAttemptDetails(result: .scored, playerNumber: 10, round: 1)
    let penaltyEvent = MatchEventRecord(
      matchTime: "91:00",
      period: 2,
      eventType: .penaltyAttempt(penaltyDetails),
      team: .home,
      details: .penalty(penaltyDetails)
    )

    let completed = CompletedMatch(match: match, events: [goalEvent, substitutionEvent, cardEvent, penaltyEvent])

    let expectation = expectation(description: "ingest-metrics")
    api.ingestExpectation = expectation

    try repository.save(completed)

    await fulfillment(of: [expectation], timeout: 2.0)
    let request = try XCTUnwrap(api.ingestRequests.first)
    let metrics = try XCTUnwrap(request.metrics)

    XCTAssertEqual(metrics.matchId, completed.id)
    XCTAssertEqual(metrics.ownerId, ownerId)
    XCTAssertEqual(metrics.totalGoals, 5)
    XCTAssertEqual(metrics.totalCards, 4)
    XCTAssertEqual(metrics.totalPenalties, 1)
    XCTAssertEqual(metrics.yellowCards, 3)
    XCTAssertEqual(metrics.redCards, 1)
    XCTAssertEqual(metrics.homeCards, 2)
    XCTAssertEqual(metrics.awayCards, 2)
    XCTAssertEqual(metrics.homeSubstitutions, 3)
    XCTAssertEqual(metrics.awaySubstitutions, 2)
    XCTAssertEqual(metrics.penaltiesScored, 1)
    XCTAssertEqual(metrics.penaltiesMissed, 0)
    XCTAssertEqual(metrics.penaltiesEnabled, true)
    XCTAssertEqual(metrics.regulationMinutes, 90)
    XCTAssertEqual(metrics.halfTimeMinutes, 15)
    XCTAssertEqual(metrics.extraTimeMinutes, nil)
    XCTAssertEqual(metrics.avgAddedTimeSeconds, 180)
  }

  func testDeleteQueuesBacklogWhenAPIFails() async throws {
    let container = try makeContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
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

    guard let matchId = try baseStore.loadAll().first?.id else {
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
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataMatchHistoryStore(container: container, auth: authProvider)
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
        events: [],
        metrics: nil
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
  private(set) var pushMetadata: [UUID: MatchSyncPushMetadata] = [:]
  private(set) var clearAllCallCount = 0

  func loadPendingDeletionIDs() -> Set<UUID> { Set(pendingIDs) }

  func addPendingDeletion(id: UUID) { if !pendingIDs.contains(id) { pendingIDs.append(id) } }

  func removePendingDeletion(id: UUID) { pendingIDs.removeAll { $0 == id } }

  func loadPendingPushMetadata() -> [UUID: MatchSyncPushMetadata] { pushMetadata }

  func updatePendingPushMetadata(_ metadata: MatchSyncPushMetadata, for id: UUID) { pushMetadata[id] = metadata }

  func removePendingPushMetadata(for id: UUID) { pushMetadata.removeValue(forKey: id) }

  func clearAll() {
    pendingIDs.removeAll()
    pushMetadata.removeAll()
    clearAllCallCount += 1
  }
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

private func makeCompletedMatch(
  homeTeamId: UUID? = nil,
  awayTeamId: UUID? = nil,
  competitionId: UUID? = nil,
  competitionName: String? = nil,
  venueId: UUID? = nil,
  venueName: String? = nil
) -> CompletedMatch {
  var match = Match(homeTeam: "Home", awayTeam: "Away")
  match.homeTeamId = homeTeamId
  match.awayTeamId = awayTeamId
  match.competitionId = competitionId
  match.competitionName = competitionName
  match.venueId = venueId
  match.venueName = venueName
  return CompletedMatch(match: match, events: [])
}
