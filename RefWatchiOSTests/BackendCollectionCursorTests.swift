import Combine
import RefWatchCore
import SwiftData
import XCTest
@testable import RefWatchiOS

@MainActor
final class BackendCollectionCursorTests: XCTestCase {
  private let ownerId = UUID(uuidString: "0190F8F4-5914-7B6C-9D6A-469A29F94001")!
  private let cachedAt = Date(timeIntervalSince1970: 1_000)
  private let remoteChangeAt = Date(timeIntervalSince1970: 2_000)
  private let pushReceiptAt = Date(timeIntervalSince1970: 3_000)

  func testTeamPushReceiptDoesNotAdvanceCollectionCursorPastEarlierTombstone() async throws {
    let auth = CollectionCursorAuthStub(ownerId: ownerId)
    let schema = Schema([TeamRecord.self, PlayerRecord.self, TeamOfficialRecord.self])
    let container = try makeContainer(schema)
    let store = SwiftDataTeamLibraryStore(container: container, auth: auth)
    let victimId = UUID()
    let victim = TeamRecord(
      id: victimId,
      name: "Deleted elsewhere",
      ownerSupabaseId: ownerId.uuidString,
      lastModifiedAt: cachedAt,
      remoteUpdatedAt: cachedAt,
      needsRemoteSync: false)
    store.context.insert(victim)
    try store.context.save()
    _ = try store.createTeam(name: "Local push", shortName: nil, division: nil)

    let tombstone = TeamRemoteContract.RemoteTeam(
      team: .init(
        id: victimId,
        ownerId: ownerId,
        name: "Deleted elsewhere",
        shortName: nil,
        division: nil,
        primaryColorHex: nil,
        secondaryColorHex: nil,
        referenceKey: nil,
        createdAt: cachedAt,
        updatedAt: remoteChangeAt,
        deletedAt: remoteChangeAt),
      members: [],
      officials: [],
      tags: [])
    let api = TeamCursorRemoteSpy(pushReceiptAt: pushReceiptAt, tombstone: tombstone)
    let repository = BackendTeamLibraryRepository(
      store: store,
      authStateProvider: auth,
      api: api,
      backlog: EmptyTeamBacklog())

    try await waitUntil {
      !api.fetchCursors.isEmpty && (try? store.fetchTeam(id: victimId)) == nil
    }

    XCTAssertEqual(api.fetchCursors.first!, BackendQuery.initialCollectionSyncFloor)
    XCTAssertNil(try store.fetchTeam(id: victimId))
    withExtendedLifetime(repository) {}
  }

  func testSchedulePushReceiptDoesNotAdvanceCollectionCursorPastEarlierTombstone() async throws {
    let auth = CollectionCursorAuthStub(ownerId: ownerId)
    let schema = Schema([
      ScheduledMatchRecord.self,
      TeamRecord.self,
      PlayerRecord.self,
      TeamOfficialRecord.self
    ])
    let container = try makeContainer(schema)
    let store = SwiftDataScheduleStore(container: container, auth: auth)
    let victimId = UUID()
    try store.save(ScheduledMatch(
      id: victimId,
      homeTeam: "Deleted",
      awayTeam: "Elsewhere",
      kickoff: cachedAt,
      ownerSupabaseId: ownerId.uuidString,
      remoteUpdatedAt: cachedAt,
      needsRemoteSync: false))
    try store.save(ScheduledMatch(
      homeTeam: "Local",
      awayTeam: "Push",
      kickoff: cachedAt,
      ownerSupabaseId: ownerId.uuidString,
      needsRemoteSync: true))

    let tombstone = ScheduleRemoteContract.RemoteScheduledMatch(
      id: victimId,
      ownerId: ownerId,
      homeTeamName: "Deleted",
      awayTeamName: "Elsewhere",
      kickoffAt: cachedAt,
      status: .scheduled,
      competitionId: nil,
      competitionName: nil,
      venueId: nil,
      venueName: nil,
      homeTeamId: nil,
      awayTeamId: nil,
      homeMatchSheet: nil,
      awayMatchSheet: nil,
      notes: nil,
      sourceDeviceId: nil,
      createdAt: cachedAt,
      updatedAt: remoteChangeAt,
      deletedAt: remoteChangeAt)
    let api = ScheduleCursorRemoteSpy(pushReceiptAt: pushReceiptAt, tombstone: tombstone)
    let repository = BackendScheduleRepository(
      store: store,
      authStateProvider: auth,
      api: api,
      backlog: EmptyScheduleBacklog(),
      pullInterval: 3_600)

    try await waitUntil {
      !api.fetchCursors.isEmpty && (try? store.record(id: victimId)) == nil
    }

    XCTAssertEqual(api.fetchCursors.first!, BackendQuery.initialCollectionSyncFloor)
    XCTAssertNil(try store.record(id: victimId))
    withExtendedLifetime(repository) {}
  }

  func testSchedulePullOverlapRetrievesLateCommitWithoutDirtyOrEqualReplayChurn() async throws {
    let auth = CollectionCursorAuthStub(ownerId: ownerId)
    let schema = Schema([
      ScheduledMatchRecord.self,
      TeamRecord.self,
      PlayerRecord.self,
      TeamOfficialRecord.self
    ])
    let container = try makeContainer(schema)
    let store = SwiftDataScheduleStore(container: container, auth: auth)
    let highWatermarkAt = Date(timeIntervalSince1970: 10_000)
    let lateCommitAt = highWatermarkAt.addingTimeInterval(
      -(BackendQuery.collectionSafetyOverlap / 2))
    let highWatermark = remoteSchedule(
      id: UUID(),
      home: "High",
      away: "Watermark",
      updatedAt: highWatermarkAt)
    let lateCommit = remoteSchedule(
      id: UUID(),
      home: "Late",
      away: "Commit",
      updatedAt: lateCommitAt)
    let api = ScheduleReplayRemoteSpy(
      highWatermark: highWatermark,
      lateCommit: lateCommit)
    let repository = BackendScheduleRepository(
      store: store,
      authStateProvider: auth,
      api: api,
      backlog: EmptyScheduleBacklog(),
      pullInterval: 3_600)

    try await waitUntil {
      api.fetchCursors.count == 1 && (try? store.record(id: highWatermark.id)) != nil
    }
    XCTAssertEqual(api.fetchCursors[0], BackendQuery.initialCollectionSyncFloor)

    try await repository.refreshFromRemote()
    try await waitUntil {
      api.fetchCursors.count >= 2 && (try? store.record(id: lateCommit.id)) != nil
    }
    XCTAssertEqual(
      api.fetchCursors[1],
      highWatermarkAt.addingTimeInterval(-BackendQuery.collectionSafetyOverlap))
    XCTAssertNotNil(try store.record(id: lateCommit.id))

    let dirtyActiveId = UUID()
    let dirtyTombstoneId = UUID()
    try store.save(ScheduledMatch(
      id: dirtyActiveId,
      homeTeam: "Local dirty active",
      awayTeam: "Must win",
      kickoff: cachedAt,
      ownerSupabaseId: ownerId.uuidString,
      remoteUpdatedAt: cachedAt,
      needsRemoteSync: true))
    try store.save(ScheduledMatch(
      id: dirtyTombstoneId,
      homeTeam: "Local dirty tombstone",
      awayTeam: "Must survive",
      kickoff: cachedAt,
      ownerSupabaseId: ownerId.uuidString,
      remoteUpdatedAt: cachedAt,
      needsRemoteSync: true))
    api.replayRows = [
      highWatermark,
      lateCommit,
      remoteSchedule(
        id: dirtyActiveId,
        home: "Remote must not overwrite",
        away: "Dirty local",
        updatedAt: highWatermarkAt.addingTimeInterval(1)),
      remoteSchedule(
        id: dirtyTombstoneId,
        home: "Remote tombstone",
        away: "Dirty local",
        updatedAt: highWatermarkAt.addingTimeInterval(1),
        deletedAt: highWatermarkAt.addingTimeInterval(1)),
    ]

    var publishedSnapshots = 0
    let changes = repository.changesPublisher
      .dropFirst()
      .sink { _ in publishedSnapshots += 1 }
    try await repository.refreshFromRemote()

    let dirtyActive = try XCTUnwrap(store.record(id: dirtyActiveId))
    XCTAssertEqual(dirtyActive.homeName, "Local dirty active")
    XCTAssertTrue(dirtyActive.needsRemoteSync)
    let dirtyTombstone = try XCTUnwrap(store.record(id: dirtyTombstoneId))
    XCTAssertEqual(dirtyTombstone.homeName, "Local dirty tombstone")
    XCTAssertTrue(dirtyTombstone.needsRemoteSync)
    XCTAssertEqual(publishedSnapshots, 0)
    changes.cancel()
    withExtendedLifetime(repository) {}
  }

  func testMatchPushAndRestoredPerRecordTimestampsDoNotAdvanceCollectionCursorPastTombstone() async throws {
    let auth = CollectionCursorAuthStub(ownerId: ownerId)
    let schema = Schema([CompletedMatchRecord.self])
    let container = try makeContainer(schema)
    let store = SwiftDataMatchHistoryStore(container: container, auth: auth)
    let victim = completedMatch(home: "Deleted", away: "Elsewhere")
    let acknowledged = completedMatch(home: "Already", away: "Acknowledged")
    let dirty = completedMatch(home: "Local", away: "Push")
    try store.save(victim)
    try store.save(acknowledged)
    try store.save(dirty)
    let victimRecord = try XCTUnwrap(store.fetchRecord(id: victim.id))
    victimRecord.needsRemoteSync = false
    victimRecord.remoteUpdatedAt = cachedAt
    let acknowledgedRecord = try XCTUnwrap(store.fetchRecord(id: acknowledged.id))
    acknowledgedRecord.needsRemoteSync = false
    acknowledgedRecord.remoteUpdatedAt = pushReceiptAt.addingTimeInterval(1_000)
    try store.context.save()

    let tombstone = MatchRemoteContract.RemoteMatchBundle(
      match: .init(
        id: victim.id,
        ownerId: ownerId,
        status: "completed",
        startedAt: cachedAt,
        completedAt: cachedAt,
        durationSeconds: 5_400,
        numberOfPeriods: 2,
        regulationMinutes: 90,
        halfTimeMinutes: 15,
        competitionId: nil,
        competitionName: nil,
        venueId: nil,
        venueName: nil,
        homeTeamId: nil,
        homeTeamName: "Deleted",
        awayTeamId: nil,
        awayTeamName: "Elsewhere",
        extraTimeEnabled: false,
        extraTimeHalfMinutes: nil,
        penaltiesEnabled: false,
        penaltyInitialRounds: 5,
        homeScore: 0,
        awayScore: 0,
        finalScore: nil,
        sourceDeviceId: nil,
        updatedAt: remoteChangeAt,
        deletedAt: remoteChangeAt),
      periods: [],
      events: [],
      metrics: nil)
    let api = MatchCursorRemoteSpy(pushReceiptAt: pushReceiptAt, tombstone: tombstone)
    let repository = BackendMatchHistoryRepository(
      store: store,
      authStateProvider: auth,
      api: api,
      backlog: EmptyMatchBacklog(),
      dateProvider: { Date(timeIntervalSince1970: 10_000) },
      pullInterval: 3_600,
      initialBackoff: 0,
      maxBackoff: 0)

    try await waitUntil {
      !api.fetchCursors.isEmpty && (try? store.fetchRecord(id: victim.id)) == nil
    }

    XCTAssertEqual(api.fetchCursors.first!, BackendQuery.initialCollectionSyncFloor)
    XCTAssertNil(try store.fetchRecord(id: victim.id))
    XCTAssertNotNil(try store.fetchRecord(id: acknowledged.id))
    withExtendedLifetime(repository) {}
  }

  func testInclusiveBoundaryPolicyOnlyAppliesStrictlyNewerRows() {
    XCTAssertTrue(BackendQuery.shouldApplyCollectionRow(
      updatedAt: remoteChangeAt,
      over: nil))
    XCTAssertFalse(BackendQuery.shouldApplyCollectionRow(
      updatedAt: remoteChangeAt,
      over: remoteChangeAt))
    XCTAssertFalse(BackendQuery.shouldApplyCollectionRow(
      updatedAt: cachedAt,
      over: remoteChangeAt))
    XCTAssertTrue(BackendQuery.shouldApplyCollectionRow(
      updatedAt: pushReceiptAt,
      over: remoteChangeAt))
    XCTAssertFalse(BackendQuery.shouldApplyCollectionRow(
      updatedAt: pushReceiptAt,
      over: cachedAt,
      localNeedsRemoteSync: true))
  }

  private func makeContainer(_ schema: Schema) throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  private func completedMatch(home: String, away: String) -> CompletedMatch {
    CompletedMatch(
      completedAt: cachedAt,
      match: Match(homeTeam: home, awayTeam: away),
      events: [],
      ownerId: ownerId.uuidString)
  }

  private func remoteSchedule(
    id: UUID,
    home: String,
    away: String,
    updatedAt: Date,
    deletedAt: Date? = nil) -> ScheduleRemoteContract.RemoteScheduledMatch
  {
    ScheduleRemoteContract.RemoteScheduledMatch(
      id: id,
      ownerId: ownerId,
      homeTeamName: home,
      awayTeamName: away,
      kickoffAt: cachedAt,
      status: .scheduled,
      competitionId: nil,
      competitionName: nil,
      venueId: nil,
      venueName: nil,
      homeTeamId: nil,
      awayTeamId: nil,
      homeMatchSheet: nil,
      awayMatchSheet: nil,
      notes: nil,
      sourceDeviceId: nil,
      createdAt: cachedAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt)
  }

  private func waitUntil(
    timeout: TimeInterval = 3,
    condition: @escaping @MainActor () -> Bool) async throws
  {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for repository synchronization")
  }
}

@MainActor
private final class CollectionCursorAuthStub: AuthStateProviding {
  private let ownerId: UUID
  private let stateSubject = PassthroughSubject<AuthState, Never>()

  init(ownerId: UUID) {
    self.ownerId = ownerId
  }

  var state: AuthState {
    .signedIn(userId: ownerId.uuidString, email: nil, displayName: nil)
  }

  var currentUserId: String? { ownerId.uuidString }
  var currentEmail: String? { nil }
  var currentDisplayName: String? { nil }
  var statePublisher: AnyPublisher<AuthState, Never> { stateSubject.eraseToAnyPublisher() }
}

@MainActor
private final class TeamCursorRemoteSpy: @preconcurrency TeamRemoteServing {
  let pushReceiptAt: Date
  let tombstone: TeamRemoteContract.RemoteTeam
  var fetchCursors: [Date?] = []
  var pushCount = 0

  init(pushReceiptAt: Date, tombstone: TeamRemoteContract.RemoteTeam) {
    self.pushReceiptAt = pushReceiptAt
    self.tombstone = tombstone
  }

  func fetchTeams(
    ownerId _: UUID,
    updatedAfter: Date?) async throws -> [TeamRemoteContract.RemoteTeam]
  {
    while pushCount == 0 { await Task.yield() }
    fetchCursors.append(updatedAfter)
    return shouldReturnTombstone(updatedAfter, tombstoneAt: tombstone.team.updatedAt)
      ? [tombstone]
      : []
  }

  func syncTeamBundle(
    _: TeamRemoteContract.TeamBundleRequest) async throws -> TeamRemoteContract.SyncResult
  {
    pushCount += 1
    return .init(updatedAt: pushReceiptAt)
  }

  func importReferenceTeamsForCurrentUser(
    seasonYear _: Int,
    competitionCodes _: [String]?) async throws -> TeamRemoteContract.ReferenceTeamImportResult
  {
    .init(importedCount: 0, updatedCount: 0, skippedCount: 0)
  }

  func deleteTeam(teamId _: UUID) async throws {}
}

@MainActor
private final class ScheduleCursorRemoteSpy: @preconcurrency ScheduleRemoteServing {
  let pushReceiptAt: Date
  let tombstone: ScheduleRemoteContract.RemoteScheduledMatch
  var fetchCursors: [Date?] = []
  var pushCount = 0

  init(pushReceiptAt: Date, tombstone: ScheduleRemoteContract.RemoteScheduledMatch) {
    self.pushReceiptAt = pushReceiptAt
    self.tombstone = tombstone
  }

  func fetchScheduledMatches(
    ownerId _: UUID,
    updatedAfter: Date?) async throws -> [ScheduleRemoteContract.RemoteScheduledMatch]
  {
    while pushCount == 0 { await Task.yield() }
    fetchCursors.append(updatedAfter)
    return shouldReturnTombstone(updatedAfter, tombstoneAt: tombstone.updatedAt)
      ? [tombstone]
      : []
  }

  func syncScheduledMatch(
    _: ScheduleRemoteContract.UpsertRequest) async throws -> ScheduleRemoteContract.SyncResult
  {
    pushCount += 1
    return .init(updatedAt: pushReceiptAt)
  }

  func deleteScheduledMatch(id _: UUID) async throws {}
}

@MainActor
private final class ScheduleReplayRemoteSpy: @preconcurrency ScheduleRemoteServing {
  let highWatermark: ScheduleRemoteContract.RemoteScheduledMatch
  let lateCommit: ScheduleRemoteContract.RemoteScheduledMatch
  var replayRows: [ScheduleRemoteContract.RemoteScheduledMatch] = []
  var fetchCursors: [Date?] = []

  init(
    highWatermark: ScheduleRemoteContract.RemoteScheduledMatch,
    lateCommit: ScheduleRemoteContract.RemoteScheduledMatch)
  {
    self.highWatermark = highWatermark
    self.lateCommit = lateCommit
  }

  func fetchScheduledMatches(
    ownerId _: UUID,
    updatedAfter: Date?) async throws -> [ScheduleRemoteContract.RemoteScheduledMatch]
  {
    fetchCursors.append(updatedAfter)
    switch fetchCursors.count {
    case 1:
      return [highWatermark]
    case 2:
      guard let updatedAfter, updatedAfter <= lateCommit.updatedAt else { return [] }
      return [lateCommit]
    default:
      return replayRows.filter { row in
        guard let updatedAfter else { return false }
        return row.updatedAt >= updatedAfter
      }
    }
  }

  func syncScheduledMatch(
    _: ScheduleRemoteContract.UpsertRequest) async throws -> ScheduleRemoteContract.SyncResult
  {
    throw ScheduleRemoteContract.APIError.invalidResponse
  }

  func deleteScheduledMatch(id _: UUID) async throws {}
}

@MainActor
private final class MatchCursorRemoteSpy: @preconcurrency MatchRemoteServing {
  let pushReceiptAt: Date
  let tombstone: MatchRemoteContract.RemoteMatchBundle
  var fetchCursors: [Date?] = []
  var pushCount = 0

  init(pushReceiptAt: Date, tombstone: MatchRemoteContract.RemoteMatchBundle) {
    self.pushReceiptAt = pushReceiptAt
    self.tombstone = tombstone
  }

  func ingestMatchBundle(
    _ request: MatchRemoteContract.MatchBundleRequest) async throws -> MatchRemoteContract.SyncResult
  {
    pushCount += 1
    return .init(matchId: request.match.id, updatedAt: pushReceiptAt)
  }

  func fetchMatchBundles(
    ownerId _: UUID,
    updatedAfter: Date?) async throws -> [MatchRemoteContract.RemoteMatchBundle]
  {
    while pushCount == 0 { await Task.yield() }
    fetchCursors.append(updatedAfter)
    return shouldReturnTombstone(updatedAfter, tombstoneAt: tombstone.match.updatedAt)
      ? [tombstone]
      : []
  }

  func deleteMatch(id _: UUID) async throws {}
}

private final class EmptyTeamBacklog: TeamLibrarySyncBacklogStoring {
  func loadPendingDeletionIDs() -> Set<UUID> { [] }
  func addPendingDeletion(id _: UUID) {}
  func removePendingDeletion(id _: UUID) {}
  func clearAll() {}
}

private final class EmptyScheduleBacklog: ScheduleSyncBacklogStoring {
  func loadPendingDeletionIDs() -> Set<UUID> { [] }
  func addPendingDeletion(id _: UUID) {}
  func removePendingDeletion(id _: UUID) {}
  func clearAll() {}
}

private final class EmptyMatchBacklog: MatchSyncBacklogStoring {
  func loadPendingDeletionIDs() -> Set<UUID> { [] }
  func addPendingDeletion(id _: UUID) {}
  func removePendingDeletion(id _: UUID) {}
  func loadPendingPushMetadata() -> [UUID: MatchSyncPushMetadata] { [:] }
  func updatePendingPushMetadata(_: MatchSyncPushMetadata, for _: UUID) {}
  func removePendingPushMetadata(for _: UUID) {}
  func clearAll() {}
}

private func shouldReturnTombstone(_ cursor: Date?, tombstoneAt: Date) -> Bool {
  guard let cursor else { return false }
  return cursor <= tombstoneAt
}
