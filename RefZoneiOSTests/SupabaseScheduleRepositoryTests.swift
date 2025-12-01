import XCTest
import Combine
import SwiftData
import RefWatchCore
@testable import RefZoneiOS

@MainActor
final class SupabaseScheduleRepositoryTests: XCTestCase {
  private var cancellables: Set<AnyCancellable> = []

  override func tearDown() {
    cancellables.removeAll()
    super.tearDown()
  }

  private func makeMemoryContainer() throws -> ModelContainer {
    let schema = Schema([ScheduledMatchRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  func testSaveQueuesPushAndClearsDirtyOnSuccess() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataScheduleStore(container: container, auth: authProvider)
    let api = MockScheduleAPI()
    let backlog = StubScheduleBacklogStore()
    let repository = SupabaseScheduleRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      pullInterval: 10
    )

    let ownerId = UUID()
    authProvider.markSignedIn(userId: ownerId.uuidString)

    let expectation = expectation(description: "sync called")
    api.syncExpectation = expectation

    try repository.save(ScheduledMatch(homeTeam: "Home", awayTeam: "Away", kickoff: Date(), needsRemoteSync: true))

    await fulfillment(of: [expectation], timeout: 1.5)
    try? await Task.sleep(nanoseconds: 200_000_000)

    guard let record = try baseStore.record(id: api.syncRequests.first?.id ?? UUID()) else {
      XCTFail("Missing record")
      return
    }

    XCTAssertFalse(record.needsRemoteSync)
    XCTAssertEqual(record.ownerSupabaseId, ownerId.uuidString)
    XCTAssertEqual(backlog.pendingIDs, [])
  }

  func testDeleteQueuesBacklogWhenAPIFails() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataScheduleStore(container: container, auth: authProvider)
    let api = MockScheduleAPI()
    api.deleteError = TestError()
    let backlog = StubScheduleBacklogStore()
    let repository = SupabaseScheduleRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      pullInterval: 10
    )

    authProvider.markSignedIn(userId: UUID().uuidString)

    try repository.save(ScheduledMatch(homeTeam: "A", awayTeam: "B", kickoff: Date(), needsRemoteSync: true))
    try? await Task.sleep(nanoseconds: 500_000_000)

    let matchId = baseStore.loadAll().first?.id ?? UUID()
    try repository.delete(id: matchId)
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(api.deleteRequests.count, 1)
    XCTAssertEqual(backlog.pendingIDs, [matchId])
    XCTAssertTrue(baseStore.loadAll().isEmpty)
  }

  func testPullRemoteInsertsMatch() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataScheduleStore(container: container, auth: authProvider)
    let api = MockScheduleAPI()
    let backlog = StubScheduleBacklogStore()

    let remoteId = UUID()
    let ownerId = UUID()
    let now = Date()
    api.fetchResult = [
      SupabaseScheduleAPI.RemoteScheduledMatch(
        id: remoteId,
        ownerId: ownerId,
        homeTeamName: "Remote FC",
        awayTeamName: "Visitors",
        kickoffAt: now,
        status: .scheduled,
        competitionId: nil,
        competitionName: "Cup",
        venueId: nil,
        venueName: nil,
        homeTeamId: nil,
        awayTeamId: nil,
        notes: nil,
        sourceDeviceId: nil,
        createdAt: now,
        updatedAt: now
      )
    ]

    let repository = SupabaseScheduleRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog,
      pullInterval: 10
    )

    let fetchExpectation = expectation(description: "fetch")
    api.fetchExpectation = fetchExpectation

    authProvider.markSignedIn(userId: ownerId.uuidString)

    await fulfillment(of: [fetchExpectation], timeout: 1.5)
    try? await Task.sleep(nanoseconds: 300_000_000)

    let matches = baseStore.loadAll()
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches.first?.id, remoteId)
    XCTAssertFalse(matches.first?.needsRemoteSync ?? true)
    XCTAssertEqual(matches.first?.competition, "Cup")
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

private final class StubScheduleBacklogStore: ScheduleSyncBacklogStoring {
  private(set) var pendingIDs: [UUID] = []

  func loadPendingDeletionIDs() -> Set<UUID> { Set(pendingIDs) }

  func addPendingDeletion(id: UUID) { if !pendingIDs.contains(id) { pendingIDs.append(id) } }

  func removePendingDeletion(id: UUID) { pendingIDs.removeAll { $0 == id } }

  func clearAll() {
    pendingIDs.removeAll()
  }
}

private final class MockScheduleAPI: SupabaseScheduleServing {
  var fetchResult: [SupabaseScheduleAPI.RemoteScheduledMatch] = []
  var fetchExpectation: XCTestExpectation?
  var syncRequests: [SupabaseScheduleAPI.UpsertRequest] = []
  var syncExpectation: XCTestExpectation?
  var deleteRequests: [UUID] = []
  var deleteError: Error?

  func fetchScheduledMatches(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseScheduleAPI.RemoteScheduledMatch] {
    fetchExpectation?.fulfill()
    return fetchResult
  }

  func syncScheduledMatch(_ request: SupabaseScheduleAPI.UpsertRequest) async throws -> SupabaseScheduleAPI.SyncResult {
    syncRequests.append(request)
    syncExpectation?.fulfill()
    return SupabaseScheduleAPI.SyncResult(updatedAt: Date())
  }

  func deleteScheduledMatch(id: UUID) async throws {
    deleteRequests.append(id)
    if let deleteError { throw deleteError }
  }
}

private struct TestError: Error {}
