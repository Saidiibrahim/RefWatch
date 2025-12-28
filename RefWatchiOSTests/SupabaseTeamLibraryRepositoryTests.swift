import XCTest
import Combine
import SwiftData
import RefWatchCore
@testable import RefWatchiOS

@MainActor
final class SupabaseTeamLibraryRepositoryTests: XCTestCase {

  private func makeMemoryContainer() throws -> ModelContainer {
    let schema = Schema([TeamRecord.self, PlayerRecord.self, TeamOfficialRecord.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  func testCreateTeamQueuesPushAndClearsDirtyOnSuccess() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataTeamLibraryStore(container: container, auth: authProvider)
    let api = MockTeamLibraryAPI()
    let backlog = StubBacklogStore()
    let repository = SupabaseTeamLibraryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    let ownerId = UUID()
    authProvider.markSignedIn(userId: ownerId.uuidString)

    let expectation = expectation(description: "sync called")
    api.syncExpectation = expectation

    let team = try repository.createTeam(name: "Leeds", shortName: "LEE", division: "U18")

    await fulfillment(of: [expectation], timeout: 1.5)

    XCTAssertEqual(api.syncRequests.count, 1)
    XCTAssertFalse(team.needsRemoteSync)
    XCTAssertEqual(team.ownerSupabaseId, ownerId.uuidString)
    XCTAssertEqual(backlog.pendingIDs, [])
  }

  func testCreateTeamSignedOut_throwsAuthError() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataTeamLibraryStore(container: container, auth: authProvider)
    let api = MockTeamLibraryAPI()
    let backlog = StubBacklogStore()
    let repository = SupabaseTeamLibraryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    XCTAssertThrowsError(try repository.createTeam(name: "Smoke", shortName: "SMK", division: "U12")) { error in
      guard case PersistenceAuthError.signedOut = error else {
        XCTFail("Expected signed-out persistence error, got: \(error)")
        return
      }
    }
    XCTAssertTrue(api.syncRequests.isEmpty)
  }

  func testDeleteTeamPersistsPendingDeletionWhenAPIFails() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataTeamLibraryStore(container: container, auth: authProvider)
    let api = MockTeamLibraryAPI()
    api.deleteError = TestError()
    let backlog = StubBacklogStore()
    let repository = SupabaseTeamLibraryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    authProvider.markSignedIn(userId: UUID().uuidString)

    let team = try repository.createTeam(name: "Ajax", shortName: "AJA", division: "Eredivisie")

    // Wait for any initial push attempt to complete.
    try? await Task.sleep(nanoseconds: 200_000_000)

    try repository.deleteTeam(team)

    // Allow the async deletion attempt to run and fail.
    try? await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(api.deleteRequests.count, 1)
    XCTAssertEqual(backlog.pendingIDs, [team.id])
    let remaining = try repository.loadAllTeams()
    XCTAssertEqual(remaining.count, 0)
  }

  func testPullRemoteInsertsTeam() async throws {
    let container = try makeMemoryContainer()
    let authProvider = StubAuthProvider()
    let baseStore = SwiftDataTeamLibraryStore(container: container, auth: authProvider)
    let api = MockTeamLibraryAPI()
    let backlog = StubBacklogStore()

    let remoteTeamId = UUID()
    let ownerId = UUID()
    let now = Date()
    api.fetchTeamsResult = [
      SupabaseTeamLibraryAPI.RemoteTeam(
        team: .init(
          id: remoteTeamId,
          ownerId: ownerId,
          name: "Remote FC",
          shortName: "RFC",
          division: "Premier",
          primaryColorHex: nil,
          secondaryColorHex: nil,
          createdAt: now,
          updatedAt: now
        ),
        members: [],
        officials: [],
        tags: []
      )
    ]

    let repository = SupabaseTeamLibraryRepository(
      store: baseStore,
      authStateProvider: authProvider,
      api: api,
      backlog: backlog
    )

    let fetchExpectation = expectation(description: "fetch remote")
    api.fetchExpectation = fetchExpectation

    authProvider.markSignedIn(userId: ownerId.uuidString)

    await fulfillment(of: [fetchExpectation], timeout: 1.5)
    try? await Task.sleep(nanoseconds: 200_000_000)

    let teams = try repository.loadAllTeams()
    XCTAssertEqual(teams.count, 1)
    XCTAssertEqual(teams.first?.id, remoteTeamId)
    XCTAssertEqual(teams.first?.name, "Remote FC")
    XCTAssertFalse(teams.first?.needsRemoteSync ?? true)
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

private final class StubBacklogStore: TeamLibrarySyncBacklogStoring {
  private(set) var pendingIDs: [UUID] = []

  func loadPendingDeletionIDs() -> Set<UUID> { Set(pendingIDs) }

  func addPendingDeletion(id: UUID) { if pendingIDs.contains(id) == false { pendingIDs.append(id) } }

  func removePendingDeletion(id: UUID) { pendingIDs.removeAll { $0 == id } }

  func clearAll() {
    pendingIDs.removeAll()
  }
}

private final class MockTeamLibraryAPI: SupabaseTeamLibraryServing {
  var syncRequests: [SupabaseTeamLibraryAPI.TeamBundleRequest] = []
  var syncExpectation: XCTestExpectation?
  var syncResult = SupabaseTeamLibraryAPI.SyncResult(updatedAt: Date())
  var deleteRequests: [UUID] = []
  var deleteError: Error?
  var fetchTeamsResult: [SupabaseTeamLibraryAPI.RemoteTeam] = []
  var fetchExpectation: XCTestExpectation?
  var fetchOwnerIds: [UUID] = []

  func fetchTeams(ownerId: UUID, updatedAfter: Date?) async throws -> [SupabaseTeamLibraryAPI.RemoteTeam] {
    fetchOwnerIds.append(ownerId)
    fetchExpectation?.fulfill()
    return fetchTeamsResult
  }

  func syncTeamBundle(_ request: SupabaseTeamLibraryAPI.TeamBundleRequest) async throws -> SupabaseTeamLibraryAPI.SyncResult {
    syncRequests.append(request)
    syncExpectation?.fulfill()
    return syncResult
  }

  func deleteTeam(teamId: UUID) async throws {
    deleteRequests.append(teamId)
    if let deleteError { throw deleteError }
  }
}

private struct TestError: Error {}
