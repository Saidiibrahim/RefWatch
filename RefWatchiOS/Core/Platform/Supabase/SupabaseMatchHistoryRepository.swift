//
//  SupabaseMatchHistoryRepository.swift
//  RefWatchiOS
//
//  Wraps the SwiftData match history store with Supabase synchronisation.
//  Local saves remain instant; the repository pushes completed matches to the
//  backend and periodically pulls remote updates for reconciliation.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SupabaseMatchHistoryRepository: MatchHistoryStoring, MatchHistorySyncControlling {
  private let store: SwiftDataMatchHistoryStore
  private let api: SupabaseMatchIngestServing
  private let authStateProvider: SupabaseAuthStateProviding
  private let backlog: MatchSyncBacklogStoring
  private let dateProvider: () -> Date
  private let deviceIdProvider: () -> String?
  private let pullInterval: TimeInterval
  private let initialBackoff: TimeInterval
  private let maxBackoff: TimeInterval
  private let log = AppLog.supabase

  private var ownerUUID: UUID?
  private var authCancellable: AnyCancellable?
  private var processingTask: Task<Void, Never>?
  private var pullTask: Task<Void, Never>?
  private var pendingPushes: Set<UUID> = []
  private var pushMetadata: [UUID: MatchSyncPushMetadata] = [:]
  private var pendingDeletions: Set<UUID> = []
  private var remoteCursor: Date?

  init(
    store: SwiftDataMatchHistoryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseMatchIngestServing,
    backlog: MatchSyncBacklogStoring,
    dateProvider: @escaping () -> Date = Date.init,
    deviceIdProvider: @escaping () -> String? = { nil },
    pullInterval: TimeInterval = 600,
    initialBackoff: TimeInterval = 5,
    maxBackoff: TimeInterval = 300)
  {
    self.store = store
    self.authStateProvider = authStateProvider
    self.api = api
    self.backlog = backlog
    self.dateProvider = dateProvider
    self.deviceIdProvider = deviceIdProvider
    self.pullInterval = pullInterval
    self.initialBackoff = initialBackoff
    self.maxBackoff = maxBackoff
    self.pendingDeletions = backlog.loadPendingDeletionIDs()
    self.pushMetadata = backlog.loadPendingPushMetadata()

    restoreStateFromStore()

    if let userId = authStateProvider.currentUserId,
       let uuid = UUID(uuidString: userId)
    {
      self.ownerUUID = uuid
    }

    self.authCancellable = authStateProvider.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          await self?.handleAuthState(state)
        }
      }

    if self.ownerUUID != nil {
      scheduleInitialSync()
    }
  }

  deinit {
    authCancellable?.cancel()
    processingTask?.cancel()
    pullTask?.cancel()
  }

  // MARK: - MatchHistoryStoring

  func loadAll() throws -> [CompletedMatch] {
    try self.store.loadAll()
  }

  func save(_ match: CompletedMatch) throws {
    _ = try ensureOwnerUUID(operation: "save match history")
    try self.store.save(match)
    guard let record = try store.fetchRecord(id: match.id) else { return }
    markRecordForSync(record)
    self.pendingDeletions.remove(match.id)
    self.backlog.removePendingDeletion(id: match.id)
    enqueuePush(for: match.id)
  }

  func delete(id: UUID) throws {
    _ = try ensureOwnerUUID(operation: "delete match history")
    self.pendingPushes.remove(id)
    clearPushMetadata(for: id)
    self.pendingDeletions.insert(id)
    self.backlog.addPendingDeletion(id: id)
    try self.store.delete(id: id)
    scheduleProcessingTask()
    publishSyncStatus()
  }

  func wipeAll() throws {
    _ = try ensureOwnerUUID(operation: "wipe match history")
    let records = try store.fetchAllRecords()
    for record in records {
      self.pendingPushes.remove(record.id)
      clearPushMetadata(for: record.id)
      self.pendingDeletions.insert(record.id)
      self.backlog.addPendingDeletion(id: record.id)
    }
    try self.store.wipeAll()
    scheduleProcessingTask()
    publishSyncStatus()
  }

  // MARK: - MatchHistorySyncControlling

  func requestManualSync() -> Bool {
    guard (try? ensureOwnerUUID(operation: "sync match history")) != nil else { return false }
    scheduleProcessingTask()
    publishSyncStatus()
    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.flushPendingDeletions()
        try await self.pushDirtyMatches()
        if let owner = self.ownerUUID {
          try await self.pullRemoteUpdates(for: owner)
        }
      } catch {
        self.log.error("Manual match sync failed: \(error.localizedDescription, privacy: .public)")
      }
    }
    return true
  }
}

// MARK: - Identity Handling

extension SupabaseMatchHistoryRepository {
  private func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      self.ownerUUID = nil
      self.remoteCursor = nil
      self.processingTask?.cancel(); self.processingTask = nil
      self.pullTask?.cancel(); self.pullTask = nil
      self.pendingPushes.removeAll()
      self.pendingDeletions.removeAll()
      self.pushMetadata.removeAll()
      self.backlog.clearAll()
      do {
        try self.store.wipeAllForLogout()
        self.log.notice("Cleared local match history after sign-out")
      } catch {
        self.log.error("Failed to wipe match history on sign-out: \(error.localizedDescription, privacy: .public)")
      }
      publishSyncStatus()
    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        self.log.error("Match sync received non-UUID Supabase id: \(userId, privacy: .public)")
        return
      }
      self.ownerUUID = uuid
      publishSyncStatus()
      self.scheduleInitialSync()
    }
  }

  private func scheduleInitialSync() {
    scheduleProcessingTask()
    self.startPeriodicPull()
    Task { [weak self] in
      await self?.performInitialSync()
    }
  }

  private func performInitialSync() async {
    guard let ownerUUID else { return }
    do {
      try await flushPendingDeletions()
      try await pushDirtyMatches()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      self.log.error("Initial match sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func startPeriodicPull() {
    self.pullTask?.cancel()
    guard self.ownerUUID != nil else { return }
    self.pullTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(self.pullInterval * 1_000_000_000))
        guard !Task.isCancelled, let ownerUUID = self.ownerUUID else { continue }
        do {
          try await self.pullRemoteUpdates(for: ownerUUID)
        } catch {
          self.log.error("Periodic match pull failed: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }
}

// MARK: - Queue Processing

extension SupabaseMatchHistoryRepository {
  fileprivate enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  private func enqueuePush(for matchId: UUID) {
    self.pendingPushes.insert(matchId)
    applyOwnerIdentityIfNeeded(for: matchId)
    ensurePushMetadata(for: matchId, initialDelay: 0)
    self.scheduleProcessingTask()
    publishSyncStatus()
  }

  private func scheduleProcessingTask() {
    guard self.processingTask == nil else { return }
    self.processingTask = Task { [weak self] in
      guard let self else { return }
      await self.drainQueues()
      await MainActor.run { self.processingTask = nil }
    }
  }

  private func drainQueues() async {
    while !Task.isCancelled {
      guard let operation = await nextOperation() else { break }
      switch operation {
      case let .delete(id):
        await performRemoteDeletion(id: id)
      case let .push(id):
        await performRemotePush(id: id)
      }
    }
  }

  private func nextOperation() async -> SyncOperation? {
    await MainActor.run {
      if let deletion = pendingDeletions.popFirst() {
        return .delete(deletion)
      }
      guard self.ownerUUID != nil else { return nil }
      if let push = pendingPushes.popFirst() {
        return .push(push)
      }
      return nil
    }
  }
}

extension SupabaseMatchHistoryRepository {
  private func ensurePushMetadata(for matchId: UUID, initialDelay: TimeInterval) {
    if self.pushMetadata[matchId] != nil { return }
    let nextAttempt = self.dateProvider().addingTimeInterval(initialDelay)
    let metadata = MatchSyncPushMetadata(retryCount: 0, nextAttempt: nextAttempt)
    self.pushMetadata[matchId] = metadata
    self.backlog.updatePendingPushMetadata(metadata, for: matchId)
  }

  private func scheduleRetry(for matchId: UUID) {
    let previousCount = self.pushMetadata[matchId]?.retryCount ?? 0
    let nextRetry = min(previousCount + 1, 10)
    let exponent = max(nextRetry - 1, 0)
    let backoff = min(maxBackoff, initialBackoff * pow(2, Double(exponent)))
    let metadata = MatchSyncPushMetadata(
      retryCount: nextRetry,
      nextAttempt: dateProvider().addingTimeInterval(backoff))
    self.pushMetadata[matchId] = metadata
    self.backlog.updatePendingPushMetadata(metadata, for: matchId)
    self.log
      .info(
        "Supabase match push retry scheduled id=\(matchId.uuidString, privacy: .public) " +
          "attempt=\(nextRetry) delay=\(backoff, privacy: .public)s")
    self.publishSyncStatus()
  }

  private func clearPushMetadata(for matchId: UUID) {
    self.pushMetadata.removeValue(forKey: matchId)
    self.backlog.removePendingPushMetadata(for: matchId)
    self.publishSyncStatus()
  }

  private func publishSyncStatus() {
    var info: [String: Any] = [
      "component": "match_history",
      "pendingPushes": pendingPushes.count,
      "pendingDeletions": self.pendingDeletions.count,
      "signedIn": self.ownerUUID != nil,
      "timestamp": self.dateProvider(),
    ]
    if let nextRetry = pushMetadata.values.map(\.nextAttempt).min() {
      info["nextRetry"] = nextRetry
    }
    NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
  }
}

// MARK: - Remote Operations

extension SupabaseMatchHistoryRepository {
  private func flushPendingDeletions() async throws {
    while let deletionId = pendingDeletions.popFirst() {
      await self.performRemoteDeletion(id: deletionId)
      try await Task.sleep(nanoseconds: 10_000_000)
    }
  }

  private func performRemoteDeletion(id: UUID) async {
    do {
      try await self.api.deleteMatch(id: id)
      self.backlog.removePendingDeletion(id: id)
    } catch {
      self.pendingDeletions.insert(id)
      self.log
        .error(
          "Supabase match delete failed id=\(id.uuidString, privacy: .public) " +
            "error=\(error.localizedDescription, privacy: .public)")
      reportMatchSyncFailure(error, context: .delete, matchId: id)
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    self.publishSyncStatus()
  }

  private func pushDirtyMatches() async throws {
    guard self.ownerUUID != nil else { return }
    let records = try store.fetchAllRecords().filter(\.needsRemoteSync)
    guard records.isEmpty == false else { return }
    for record in records {
      self.pendingPushes.insert(record.id)
      applyOwnerIdentityIfNeeded(for: record.id)
      self.ensurePushMetadata(for: record.id, initialDelay: 0)
    }
    self.scheduleProcessingTask()
    self.publishSyncStatus()
  }

  private func performRemotePush(id: UUID) async {
    self.ensurePushMetadata(for: id, initialDelay: 0)

    if let metadata = pushMetadata[id] {
      let now = self.dateProvider()
      if metadata.nextAttempt > now {
        let delay = metadata.nextAttempt.timeIntervalSince(now)
        let clampedDelay = min(delay, maxBackoff)
        let nanoseconds = UInt64(max(clampedDelay, 0) * 1_000_000_000)
        if nanoseconds > 0 {
          try? await Task.sleep(nanoseconds: nanoseconds)
        }
      }
    }

    guard let ownerUUID else {
      self.scheduleRetry(for: id)
      self.pendingPushes.insert(id)
      return
    }

    guard let record = try? store.fetchRecord(id: id),
          let snapshot = SwiftDataMatchHistoryStore.decode(record.payload)
    else {
      self.clearPushMetadata(for: id)
      return
    }

    guard let request = makeMatchBundleRequest(for: record, snapshot: snapshot, ownerUUID: ownerUUID) else {
      self.scheduleRetry(for: id)
      self.pendingPushes.insert(id)
      return
    }

    do {
      let result = try await api.ingestMatchBundle(request)
      record.needsRemoteSync = false
      record.remoteUpdatedAt = result.updatedAt
      record.lastSyncedAt = self.dateProvider()
      record.ownerId = ownerUUID.uuidString
      if record.sourceDeviceId == nil {
        record.sourceDeviceId = self.deviceIdProvider()
      }
      try self.store.context.save()
      NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
      self.remoteCursor = max(self.remoteCursor ?? result.updatedAt, result.updatedAt)
      self.clearPushMetadata(for: id)
    } catch {
      self.scheduleRetry(for: id)
      self.pendingPushes.insert(id)
      self.log
        .error(
          "Supabase match push failed id=\(id.uuidString, privacy: .public) " +
            "error=\(error.localizedDescription, privacy: .public)")
      reportMatchSyncFailure(error, context: .push, matchId: id)
    }
  }

  private func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    #if DEBUG
    self.log.debug("Match history pull started for owner=\(ownerUUID.uuidString, privacy: .public)")
    #endif
    let remoteBundles = try await api.fetchMatchBundles(ownerId: ownerUUID, updatedAfter: self.remoteCursor)
    #if DEBUG
    self.log.debug("Fetched \(remoteBundles.count) remote bundles")
    #endif
    guard remoteBundles.isEmpty == false else { return }

    var didChange = false
    for bundle in remoteBundles {
      if self.pendingDeletions.contains(bundle.match.id) {
        continue
      }
      if let record = try store.fetchRecord(id: bundle.match.id) {
        let localDirty = record.needsRemoteSync
        let localRemoteDate = record.remoteUpdatedAt ?? .distantPast
        if localDirty, bundle.match.updatedAt <= localRemoteDate {
          continue
        }
        if let merged = try merge(remote: bundle, into: record) {
          record.payload = merged
          record.completedAt = bundle.match.completedAt
          record.ownerId = bundle.match.ownerId.uuidString
          record.homeTeam = bundle.match.homeTeamName
          record.awayTeam = bundle.match.awayTeamName
          record.homeScore = bundle.match.homeScore
          record.awayScore = bundle.match.awayScore
          record.homeTeamId = bundle.match.homeTeamId
          record.awayTeamId = bundle.match.awayTeamId
          record.competitionId = bundle.match.competitionId
          record.competitionName = bundle.match.competitionName
          record.venueId = bundle.match.venueId
          record.venueName = bundle.match.venueName
          record.needsRemoteSync = false
          record.remoteUpdatedAt = bundle.match.updatedAt
          record.lastSyncedAt = self.dateProvider()
          record.sourceDeviceId = bundle.match.sourceDeviceId ?? record.sourceDeviceId
          self.clearPushMetadata(for: bundle.match.id)
          didChange = true
        }
      } else {
        if let record = try insertRemote(bundle, ownerUUID: ownerUUID) {
          self.store.context.insert(record)
          self.clearPushMetadata(for: bundle.match.id)
          didChange = true
        }
      }
    }

    if didChange {
      try self.store.context.save()
      NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
      #if DEBUG
      self.log
        .debug(
          "Match history sync complete: \(remoteBundles.count) bundles processed, " +
            "posting .matchHistoryDidChange notification")
      #endif
    }

    if let maxDate = remoteBundles.map(\.match.updatedAt).max() {
      self.remoteCursor = max(self.remoteCursor ?? maxDate, maxDate)
    }
    self.publishSyncStatus()
  }
}

// MARK: - Helpers

extension SupabaseMatchHistoryRepository {
  fileprivate enum MatchSyncFailureContext { case push, delete }

  private func reportMatchSyncFailure(_ error: Error, context: MatchSyncFailureContext, matchId: UUID) {
    let description = String(describing: error)
    let message: String
    let breadcrumb: String

    if self.isMissingIngestFunctionError(error) {
      message = "matches-ingest edge function missing (404)"
      breadcrumb = "match_history.ingest.404"
    } else {
      let phase = context == .push ? "ingest" : "delete"
      message = "Supabase match \(phase) failed: \(description)"
      breadcrumb = "match_history.\(phase)"
    }

    NotificationCenter.default.post(
      name: .syncNonrecoverableError,
      object: nil,
      userInfo: [
        "error": "\(message) [match_id=\(matchId.uuidString)]",
        "context": breadcrumb,
      ])
  }

  private func isMissingIngestFunctionError(_ error: Error) -> Bool {
    let description = String(describing: error).lowercased()
    if description.contains("matches-ingest") {
      if description.contains("404") || description.contains("not found") {
        return true
      }
    }
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorResourceUnavailable {
      return true
    }
    if nsError.code == 404 { return true }
    return false
  }

  private func restoreStateFromStore() {
    do {
      let records = try store.fetchAllRecords()
      self.pendingPushes = Set(records.filter(\.needsRemoteSync).map(\.id))
      self.remoteCursor = records.compactMap(\.remoteUpdatedAt).max()
      let validIds = self.pendingPushes
      let staleIds = Set(pushMetadata.keys).subtracting(validIds)
      for stale in staleIds {
        self.clearPushMetadata(for: stale)
      }
      for id in validIds {
        self.ensurePushMetadata(for: id, initialDelay: 0)
      }
      self.publishSyncStatus()
    } catch {
      self.log.error("Failed to restore match sync state: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func markRecordForSync(_ record: CompletedMatchRecord) {
    record.needsRemoteSync = true
    if record.ownerId == nil, let ownerUUID {
      record.ownerId = ownerUUID.uuidString
    }
    if record.sourceDeviceId == nil {
      record.sourceDeviceId = self.deviceIdProvider()
    }
    try? self.store.context.save()
  }

  private func ensureOwnerUUID(operation: String) throws -> UUID {
    if let ownerUUID {
      return ownerUUID
    }
    if let userId = authStateProvider.currentUserId, let resolved = UUID(uuidString: userId) {
      ownerUUID = resolved
      return resolved
    }
    throw PersistenceAuthError.signedOut(operation: operation)
  }

  private func applyOwnerIdentityIfNeeded(for matchId: UUID) {
    guard let ownerUUID else { return }
    guard let record = try? store.fetchRecord(id: matchId) else { return }
    if record.ownerId != ownerUUID.uuidString {
      record.ownerId = ownerUUID.uuidString
      try? self.store.context.save()
    }
  }

  private func makeMatchBundleRequest(
    for record: CompletedMatchRecord,
    snapshot: CompletedMatch,
    ownerUUID: UUID) -> SupabaseMatchIngestService.MatchBundleRequest?
  {
    let match = snapshot.match
    let matchPayload = SupabaseMatchIngestService.MatchBundleRequest.MatchPayload(
      id: snapshot.id,
      ownerId: ownerUUID,
      status: "completed",
      scheduledMatchId: nil,
      startedAt: match.startTime,
      completedAt: snapshot.completedAt,
      durationSeconds: Int(match.duration.rounded()),
      numberOfPeriods: max(1, match.numberOfPeriods),
      regulationMinutes: Int(match.duration / 60),
      halfTimeMinutes: Int(match.halfTimeLength / 60),
      competitionId: match.competitionId,
      competitionName: match.competitionName,
      venueId: match.venueId,
      venueName: match.venueName,
      homeTeamId: match.homeTeamId,
      homeTeamName: match.homeTeam,
      awayTeamId: match.awayTeamId,
      awayTeamName: match.awayTeam,
      extraTimeEnabled: match.hasExtraTime,
      extraTimeHalfMinutes: match.hasExtraTime ? Int(match.extraTimeHalfLength / 60) : nil,
      penaltiesEnabled: match.hasPenalties,
      penaltyInitialRounds: match.penaltyInitialRounds,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      finalScore: self.makeFinalScorePayload(from: match),
      sourceDeviceId: record.sourceDeviceId ?? self.deviceIdProvider())

    let periodSummaries = self.makePeriodSummaries(
      for: match,
      events: snapshot.events,
      finalHome: match.homeScore,
      finalAway: match.awayScore)
    let periods = periodSummaries.map { summary in
      SupabaseMatchIngestService.MatchBundleRequest.PeriodPayload(
        id: UUID(),
        matchId: snapshot.id,
        index: summary.index,
        regulationSeconds: summary.regulationSeconds,
        addedTimeSeconds: summary.addedTimeSeconds,
        result: summary.partialScore.map { score in
          SupabaseMatchIngestService.MatchBundleRequest.PeriodResultPayload(
            homeScore: score.home,
            awayScore: score.away)
        })
    }

    let events = snapshot.events.map { event in
      SupabaseMatchIngestService.MatchBundleRequest.EventPayload(
        id: event.id,
        matchId: snapshot.id,
        occurredAt: event.actualTime,
        periodIndex: event.period,
        clockSeconds: clockSeconds(for: event, match: match),
        matchTimeLabel: event.matchTime,
        eventType: supabaseEventType(for: event),
        payload: event,
        teamSide: supabaseTeamSide(for: event.team))
    }

    let metrics = self.makeMetricsPayload(
      ownerId: ownerUUID,
      matchPayload: matchPayload,
      match: match,
      periodSummaries: periodSummaries,
      events: snapshot.events)

    return SupabaseMatchIngestService.MatchBundleRequest(
      match: matchPayload,
      periods: periods,
      events: events,
      metrics: metrics)
  }

  private func makeMetricsPayload(
    ownerId: UUID,
    matchPayload: SupabaseMatchIngestService.MatchBundleRequest.MatchPayload,
    match: Match,
    periodSummaries: [PeriodSummary],
    events: [MatchEventRecord]) -> SupabaseMatchIngestService.MatchBundleRequest.MetricsPayload
  {
    let finalScore = matchPayload.finalScore
    let homeYellow = finalScore?.homeYellowCards ?? match.homeYellowCards
    let awayYellow = finalScore?.awayYellowCards ?? match.awayYellowCards
    let homeRed = finalScore?.homeRedCards ?? match.homeRedCards
    let awayRed = finalScore?.awayRedCards ?? match.awayRedCards
    let yellowCards = homeYellow + awayYellow
    let redCards = homeRed + awayRed
    let homeCards = homeYellow + homeRed
    let awayCards = awayYellow + awayRed

    let penaltyStats = penaltyStats(from: events)
    let avgAddedSeconds = averageAddedTime(in: periodSummaries)
    let extraTimeMinutes = matchPayload.extraTimeHalfMinutes.map { $0 * 2 }

    return SupabaseMatchIngestService.MatchBundleRequest.MetricsPayload(
      matchId: matchPayload.id,
      ownerId: ownerId,
      regulationMinutes: matchPayload.regulationMinutes,
      halfTimeMinutes: matchPayload.halfTimeMinutes,
      extraTimeMinutes: extraTimeMinutes,
      penaltiesEnabled: matchPayload.penaltiesEnabled,
      totalGoals: matchPayload.homeScore + matchPayload.awayScore,
      totalCards: yellowCards + redCards,
      totalPenalties: penaltyStats.attempts,
      yellowCards: yellowCards,
      redCards: redCards,
      homeCards: homeCards,
      awayCards: awayCards,
      homeSubstitutions: finalScore?.homeSubstitutions ?? match.homeSubs,
      awaySubstitutions: finalScore?.awaySubstitutions ?? match.awaySubs,
      penaltiesScored: penaltyStats.scored,
      penaltiesMissed: penaltyStats.missed,
      avgAddedTimeSeconds: avgAddedSeconds)
  }

  private func makeFinalScorePayload(from match: Match) -> SupabaseMatchIngestService.MatchBundleRequest
  .FinalScorePayload {
    SupabaseMatchIngestService.MatchBundleRequest.FinalScorePayload(
      home: match.homeScore,
      away: match.awayScore,
      homeYellowCards: match.homeYellowCards,
      awayYellowCards: match.awayYellowCards,
      homeRedCards: match.homeRedCards,
      awayRedCards: match.awayRedCards,
      homeSubstitutions: match.homeSubs,
      awaySubstitutions: match.awaySubs)
  }

  private func makePeriodSummaries(
    for match: Match,
    events: [MatchEventRecord],
    finalHome: Int,
    finalAway: Int) -> [PeriodSummary]
  {
    let indices = periodIndices(from: events, match: match)
    var summaries: [PeriodSummary] = []
    for index in indices {
      let regulation = regulationSeconds(for: index, match: match)
      let periodEvents = events.filter { $0.period == index }
      let maxClock = periodEvents.map { clockSeconds(for: $0, match: match) }.max() ?? 0
      let added = max(0, maxClock - regulation)
      let partial = self.partialScore(upTo: index, events: events)
      summaries.append(PeriodSummary(
        index: index,
        regulationSeconds: regulation,
        addedTimeSeconds: added,
        partialScore: partial))
    }
    // Ensure summaries are sorted by index
    return summaries.sorted(by: { $0.index < $1.index })
  }

  private func partialScore(upTo period: Int, events: [MatchEventRecord]) -> (home: Int, away: Int)? {
    guard period > 0 else { return nil }
    var home = 0
    var away = 0
    for event in events where event.period <= period {
      if case let .goal(details) = event.eventType {
        let scoringSide: TeamSide? = if details.goalType == .ownGoal {
          event.team?.opponent
        } else {
          event.team
        }
        switch scoringSide {
        case .home?: home += 1
        case .away?: away += 1
        default: break
        }
      }
    }
    return (home, away)
  }

  private func insertRemote(
    _ bundle: SupabaseMatchIngestService.RemoteMatchBundle,
    ownerUUID: UUID) throws -> CompletedMatchRecord?
  {
    guard let snapshot = makeCompletedMatch(from: bundle) else { return nil }
    let payload = try SwiftDataMatchHistoryStore.encode(snapshot)
    let record = CompletedMatchRecord(
      id: snapshot.id,
      completedAt: snapshot.completedAt,
      ownerId: snapshot.ownerId,
      homeTeam: snapshot.match.homeTeam,
      awayTeam: snapshot.match.awayTeam,
      homeScore: snapshot.match.homeScore,
      awayScore: snapshot.match.awayScore,
      homeTeamId: snapshot.match.homeTeamId,
      awayTeamId: snapshot.match.awayTeamId,
      competitionId: snapshot.match.competitionId,
      competitionName: snapshot.match.competitionName,
      venueId: snapshot.match.venueId,
      venueName: snapshot.match.venueName,
      payload: payload,
      remoteUpdatedAt: bundle.match.updatedAt,
      needsRemoteSync: false,
      lastSyncedAt: self.dateProvider(),
      sourceDeviceId: bundle.match.sourceDeviceId)
    return record
  }

  private func merge(
    remote bundle: SupabaseMatchIngestService.RemoteMatchBundle,
    into record: CompletedMatchRecord) throws -> Data?
  {
    guard let snapshot = makeCompletedMatch(from: bundle) else { return nil }
    return try SwiftDataMatchHistoryStore.encode(snapshot)
  }

  private func makeCompletedMatch(from bundle: SupabaseMatchIngestService.RemoteMatchBundle) -> CompletedMatch? {
    let remote = bundle.match
    var match = Match(
      id: remote.id,
      homeTeam: remote.homeTeamName,
      awayTeam: remote.awayTeamName,
      duration: remote.regulationMinutes.map { TimeInterval($0 * 60) } ?? 90 * 60,
      numberOfPeriods: max(1, remote.numberOfPeriods),
      halfTimeLength: remote.halfTimeMinutes.map { TimeInterval($0 * 60) } ?? 15 * 60,
      extraTimeHalfLength: remote.extraTimeHalfMinutes.map { TimeInterval($0 * 60) } ?? 0,
      hasExtraTime: remote.extraTimeEnabled,
      hasPenalties: remote.penaltiesEnabled,
      penaltyInitialRounds: remote.penaltyInitialRounds)
    match.startTime = remote.startedAt
    match.homeScore = remote.homeScore
    match.awayScore = remote.awayScore
    match.homeTeamId = remote.homeTeamId
    match.awayTeamId = remote.awayTeamId
    match.competitionId = remote.competitionId
    match.competitionName = remote.competitionName
    match.venueId = remote.venueId
    match.venueName = remote.venueName

    if let final = remote.finalScore {
      match.homeYellowCards = final.homeYellowCards
      match.awayYellowCards = final.awayYellowCards
      match.homeRedCards = final.homeRedCards
      match.awayRedCards = final.awayRedCards
      match.homeSubs = final.homeSubstitutions
      match.awaySubs = final.awaySubstitutions
    } else {
      let stats = deriveStats(from: bundle.events)
      match.homeYellowCards = stats.homeYellow
      match.awayYellowCards = stats.awayYellow
      match.homeRedCards = stats.homeRed
      match.awayRedCards = stats.awayRed
      match.homeSubs = stats.homeSubs
      match.awaySubs = stats.awaySubs
    }

    let events = bundle.events.compactMap { self.makeEvent(from: $0) }

    return CompletedMatch(
      id: remote.id,
      completedAt: remote.completedAt,
      match: match,
      events: events,
      ownerId: remote.ownerId.uuidString)
  }

  private func makeEvent(from remote: SupabaseMatchIngestService.RemoteEvent) -> MatchEventRecord? {
    if let payload = remote.payload {
      return MatchEventRecord(
        id: remote.id,
        timestamp: payload.timestamp,
        actualTime: remote.occurredAt,
        matchTime: remote.matchTimeLabel,
        period: remote.periodIndex,
        eventType: payload.eventType,
        team: remote.teamSide.flatMap(domainTeamSide) ?? payload.team,
        details: payload.details)
    }

    guard let eventType = domainEventType(from: remote.eventType) else { return nil }
    return MatchEventRecord(
      id: remote.id,
      timestamp: remote.occurredAt,
      actualTime: remote.occurredAt,
      matchTime: remote.matchTimeLabel,
      period: remote.periodIndex,
      eventType: eventType,
      team: remote.teamSide.flatMap(domainTeamSide),
      details: .general)
  }
}

// MARK: - Derived Helpers

extension SupabaseMatchHistoryRepository {
  fileprivate struct PeriodSummary {
    let index: Int
    let regulationSeconds: Int
    let addedTimeSeconds: Int
    let partialScore: (home: Int, away: Int)?
  }

  fileprivate struct DerivedStats {
    let homeYellow: Int
    let awayYellow: Int
    let homeRed: Int
    let awayRed: Int
    let homeSubs: Int
    let awaySubs: Int
  }

  fileprivate struct PenaltyStats {
    let attempts: Int
    let scored: Int
    let missed: Int
  }

  private func deriveStats(from events: [SupabaseMatchIngestService.RemoteEvent]) -> DerivedStats {
    var homeYellow = 0
    var awayYellow = 0
    var homeRed = 0
    var awayRed = 0
    var homeSubs = 0
    var awaySubs = 0

    for remote in events {
      guard let team = remote.teamSide.flatMap(domainTeamSide) else { continue }
      switch remote.eventType {
      case "card_yellow":
        if team == .home { homeYellow += 1 } else { awayYellow += 1 }
      case "card_red", "card_second_yellow":
        if team == .home { homeRed += 1 } else { awayRed += 1 }
      case "substitution":
        if team == .home { homeSubs += 1 } else { awaySubs += 1 }
      default:
        continue
      }
    }

    return DerivedStats(
      homeYellow: homeYellow,
      awayYellow: awayYellow,
      homeRed: homeRed,
      awayRed: awayRed,
      homeSubs: homeSubs,
      awaySubs: awaySubs)
  }

  private func penaltyStats(from events: [MatchEventRecord]) -> PenaltyStats {
    var attempts = 0
    var scored = 0
    var missed = 0
    var sawExplicitAttempts = false

    for event in events {
      switch event.eventType {
      case let .penaltyAttempt(details):
        sawExplicitAttempts = true
        attempts += 1
        if details.result == .scored {
          scored += 1
        } else {
          missed += 1
        }
      default:
        continue
      }
    }

    if sawExplicitAttempts == false {
      for event in events {
        if case let .goal(details) = event.eventType, details.goalType == .penalty {
          attempts += 1
          scored += 1
        }
      }
    }

    return PenaltyStats(attempts: attempts, scored: scored, missed: missed)
  }

  private func averageAddedTime(in summaries: [PeriodSummary]) -> Int {
    guard summaries.isEmpty == false else { return 0 }
    let total = summaries.reduce(0) { $0 + max(0, $1.addedTimeSeconds) }
    let average = Double(total) / Double(summaries.count)
    return Int(average.rounded())
  }

  private func supabaseTeamSide(for team: TeamSide?) -> String? {
    guard let team else { return nil }
    switch team {
    case .home: return "home"
    case .away: return "away"
    }
  }

  private func domainTeamSide(from value: String?) -> TeamSide? {
    guard let value else { return nil }
    switch value.lowercased() {
    case "home": return .home
    case "away": return .away
    default: return nil
    }
  }

  private func supabaseEventType(for event: MatchEventRecord) -> String {
    switch event.eventType {
    case .goal:
      "goal"
    case let .card(details):
      switch details.cardType {
      case .yellow: "card_yellow"
      case .red: "card_red"
      }
    case .substitution:
      "substitution"
    case .kickOff:
      "kick_off"
    case .periodStart:
      "period_start"
    case .halfTime:
      "half_time"
    case .periodEnd:
      "period_end"
    case .matchEnd:
      "match_end"
    case .penaltiesStart:
      "penalties_start"
    case .penaltyAttempt:
      "penalty_attempt"
    case .penaltiesEnd:
      "penalties_end"
    }
  }

  private func domainEventType(from supabaseType: String) -> MatchEventType? {
    switch supabaseType {
    case "goal":
      .goal(GoalDetails(goalType: .regular, playerNumber: nil, playerName: nil))
    case "penalty_attempt":
      .penaltyAttempt(PenaltyAttemptDetails(result: .missed, playerNumber: nil, round: 0))
    case "penalties_start":
      .penaltiesStart
    case "penalties_end":
      .penaltiesEnd
    case "kick_off":
      .kickOff
    case "period_start":
      .periodStart(1)
    case "period_end":
      .periodEnd(1)
    case "half_time":
      .halfTime
    case "match_end":
      .matchEnd
    case "card_yellow":
      .card(CardDetails(
        cardType: .yellow,
        recipientType: .player,
        playerNumber: nil,
        playerName: nil,
        officialRole: nil,
        reason: ""))
    case "card_red", "card_second_yellow":
      .card(CardDetails(
        cardType: .red,
        recipientType: .player,
        playerNumber: nil,
        playerName: nil,
        officialRole: nil,
        reason: ""))
    case "substitution":
      .substitution(SubstitutionDetails(playerOut: nil, playerIn: nil, playerOutName: nil, playerInName: nil))
    default:
      nil
    }
  }

  private func periodIndices(from events: [MatchEventRecord], match: Match) -> [Int] {
    let eventPeriods = Set(events.map(\.period))
    if eventPeriods.isEmpty {
      return Array(1...max(1, match.numberOfPeriods))
    }
    return Array(eventPeriods).sorted()
  }

  private func regulationSeconds(for period: Int, match: Match) -> Int {
    if period <= match.numberOfPeriods {
      let total = Int(match.duration)
      let periods = max(1, match.numberOfPeriods)
      return total / periods
    } else {
      return Int(match.extraTimeHalfLength)
    }
  }

  private func clockSeconds(for event: MatchEventRecord, match: Match) -> Int {
    guard let total = totalSeconds(from: event.matchTime) else { return 0 }
    let prior = self.priorRegulationSeconds(before: event.period, match: match)
    return max(0, total - prior)
  }

  private func priorRegulationSeconds(before period: Int, match: Match) -> Int {
    guard period > 1 else { return 0 }
    var total = 0
    for index in 1..<period {
      total += self.regulationSeconds(for: index, match: match)
    }
    return total
  }

  private func totalSeconds(from label: String) -> Int? {
    let components = label.split(separator: ":")
    guard components.count == 2,
          let minutes = Int(components[0]),
          let seconds = Int(components[1])
    else {
      return nil
    }
    return minutes * 60 + seconds
  }
}

extension TeamSide {
  fileprivate var opponent: TeamSide {
    switch self {
    case .home: .away
    case .away: .home
    }
  }
}
