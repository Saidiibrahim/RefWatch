//
//  SupabaseMatchHistoryRepository.swift
//  RefZoneiOS
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
  private let log = AppLog.supabase

  private var ownerUUID: UUID?
  private var authCancellable: AnyCancellable?
  private var processingTask: Task<Void, Never>?
  private var pullTask: Task<Void, Never>?
  private var pendingPushes: Set<UUID> = []
  private var pendingDeletions: Set<UUID>
  private var remoteCursor: Date?

  init(
    store: SwiftDataMatchHistoryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseMatchIngestServing = SupabaseMatchIngestService(),
    backlog: MatchSyncBacklogStoring = SupabaseMatchSyncBacklogStore(),
    dateProvider: @escaping () -> Date = Date.init,
    deviceIdProvider: @escaping () -> String? = { nil },
    pullInterval: TimeInterval = 600
  ) {
    self.store = store
    self.authStateProvider = authStateProvider
    self.api = api
    self.backlog = backlog
    self.dateProvider = dateProvider
    self.deviceIdProvider = deviceIdProvider
    self.pullInterval = pullInterval
    self.pendingDeletions = backlog.loadPendingDeletionIDs()

    restoreStateFromStore()

    if let userId = authStateProvider.currentUserId,
       let uuid = UUID(uuidString: userId) {
      ownerUUID = uuid
    }

    authCancellable = authStateProvider.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          await self?.handleAuthState(state)
        }
      }

    if ownerUUID != nil {
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
    try store.loadAll()
  }

  func save(_ match: CompletedMatch) throws {
    try store.save(match)
    guard let record = try store.fetchRecord(id: match.id) else { return }
    markRecordForSync(record)
    pendingDeletions.remove(match.id)
    backlog.removePendingDeletion(id: match.id)
    enqueuePush(for: match.id)
  }

  func delete(id: UUID) throws {
    pendingPushes.remove(id)
    pendingDeletions.insert(id)
    backlog.addPendingDeletion(id: id)
    try store.delete(id: id)
    scheduleProcessingTask()
  }

  func wipeAll() throws {
    let records = try store.fetchAllRecords()
    for record in records {
      pendingPushes.remove(record.id)
      pendingDeletions.insert(record.id)
      backlog.addPendingDeletion(id: record.id)
    }
    try store.wipeAll()
    scheduleProcessingTask()
  }

  // MARK: - MatchHistorySyncControlling

  func requestManualSync() -> Bool {
    guard ownerUUID != nil else { return false }
    scheduleProcessingTask()
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

private extension SupabaseMatchHistoryRepository {
  func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      ownerUUID = nil
      remoteCursor = nil
      processingTask?.cancel(); processingTask = nil
      pullTask?.cancel(); pullTask = nil
    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        log.error("Match sync received non-UUID Supabase id: \(userId, privacy: .public)")
        return
      }
      ownerUUID = uuid
      scheduleInitialSync()
    }
  }

  func scheduleInitialSync() {
    scheduleProcessingTask()
    startPeriodicPull()
    Task { [weak self] in
      await self?.performInitialSync()
    }
  }

  func performInitialSync() async {
    guard let ownerUUID else { return }
    do {
      try await flushPendingDeletions()
      try await pushDirtyMatches()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      log.error("Initial match sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func startPeriodicPull() {
    pullTask?.cancel()
    guard ownerUUID != nil else { return }
    pullTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(pullInterval * 1_000_000_000))
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

private extension SupabaseMatchHistoryRepository {
  enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  func enqueuePush(for matchId: UUID) {
    pendingPushes.insert(matchId)
    applyOwnerIdentityIfNeeded(for: matchId)
    scheduleProcessingTask()
  }

  func scheduleProcessingTask() {
    guard processingTask == nil else { return }
    processingTask = Task { [weak self] in
      guard let self else { return }
      await self.drainQueues()
      await MainActor.run { self.processingTask = nil }
    }
  }

  func drainQueues() async {
    while !Task.isCancelled {
      guard let operation = await nextOperation() else { break }
      switch operation {
      case .delete(let id):
        await performRemoteDeletion(id: id)
      case .push(let id):
        await performRemotePush(id: id)
      }
    }
  }

  func nextOperation() async -> SyncOperation? {
    await MainActor.run {
      if let deletion = pendingDeletions.popFirst() {
        return .delete(deletion)
      }
      guard ownerUUID != nil else { return nil }
      if let push = pendingPushes.popFirst() {
        return .push(push)
      }
      return nil
    }
  }
}

// MARK: - Remote Operations

private extension SupabaseMatchHistoryRepository {
  func flushPendingDeletions() async throws {
    while let deletionId = pendingDeletions.popFirst() {
      await performRemoteDeletion(id: deletionId)
      try await Task.sleep(nanoseconds: 10_000_000)
    }
  }

  func performRemoteDeletion(id: UUID) async {
    do {
      try await api.deleteMatch(id: id)
      backlog.removePendingDeletion(id: id)
    } catch {
      pendingDeletions.insert(id)
      log.error("Supabase match delete failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func pushDirtyMatches() async throws {
    guard ownerUUID != nil else { return }
    let records = try store.fetchAllRecords().filter { $0.needsRemoteSync }
    guard records.isEmpty == false else { return }
    for record in records {
      pendingPushes.insert(record.id)
      applyOwnerIdentityIfNeeded(for: record.id)
    }
    scheduleProcessingTask()
  }

  func performRemotePush(id: UUID) async {
    guard let ownerUUID else {
      pendingPushes.insert(id)
      return
    }
    guard let record = try? store.fetchRecord(id: id),
          let snapshot = SwiftDataMatchHistoryStore.decode(record.payload) else {
      return
    }

    guard let request = makeMatchBundleRequest(for: record, snapshot: snapshot, ownerUUID: ownerUUID) else {
      pendingPushes.insert(id)
      return
    }

    do {
      let result = try await api.ingestMatchBundle(request)
      record.needsRemoteSync = false
      record.remoteUpdatedAt = result.updatedAt
      record.lastSyncedAt = dateProvider()
      record.ownerId = ownerUUID.uuidString
      if record.sourceDeviceId == nil {
        record.sourceDeviceId = deviceIdProvider()
      }
      try store.context.save()
      NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
      remoteCursor = max(remoteCursor ?? result.updatedAt, result.updatedAt)
    } catch {
      pendingPushes.insert(id)
      log.error("Supabase match push failed id=\(id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let remoteBundles = try await api.fetchMatchBundles(ownerId: ownerUUID, updatedAfter: remoteCursor)
    guard remoteBundles.isEmpty == false else { return }

    var didChange = false
    for bundle in remoteBundles {
      if pendingDeletions.contains(bundle.match.id) {
        continue
      }
      if let record = try store.fetchRecord(id: bundle.match.id) {
        let localDirty = record.needsRemoteSync
        let localRemoteDate = record.remoteUpdatedAt ?? .distantPast
        if localDirty && bundle.match.updatedAt <= localRemoteDate {
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
          record.needsRemoteSync = false
          record.remoteUpdatedAt = bundle.match.updatedAt
          record.lastSyncedAt = dateProvider()
          record.sourceDeviceId = bundle.match.sourceDeviceId ?? record.sourceDeviceId
          didChange = true
        }
      } else {
        if let record = try insertRemote(bundle, ownerUUID: ownerUUID) {
          store.context.insert(record)
          didChange = true
        }
      }
    }

    if didChange {
      try store.context.save()
      NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
    }

    if let maxDate = remoteBundles.map({ $0.match.updatedAt }).max() {
      remoteCursor = max(remoteCursor ?? maxDate, maxDate)
    }
  }
}

// MARK: - Helpers

private extension SupabaseMatchHistoryRepository {
  func restoreStateFromStore() {
    do {
      let records = try store.fetchAllRecords()
      pendingPushes = Set(records.filter { $0.needsRemoteSync }.map { $0.id })
      remoteCursor = records.compactMap { $0.remoteUpdatedAt }.max()
    } catch {
      log.error("Failed to restore match sync state: \(error.localizedDescription, privacy: .public)")
    }
  }

  func markRecordForSync(_ record: CompletedMatchRecord) {
    record.needsRemoteSync = true
    if record.ownerId == nil, let ownerUUID {
      record.ownerId = ownerUUID.uuidString
    }
    if record.sourceDeviceId == nil {
      record.sourceDeviceId = deviceIdProvider()
    }
    try? store.context.save()
  }

  func applyOwnerIdentityIfNeeded(for matchId: UUID) {
    guard let ownerUUID else { return }
    guard let record = try? store.fetchRecord(id: matchId) else { return }
    if record.ownerId != ownerUUID.uuidString {
      record.ownerId = ownerUUID.uuidString
      try? store.context.save()
    }
  }

  func makeMatchBundleRequest(
    for record: CompletedMatchRecord,
    snapshot: CompletedMatch,
    ownerUUID: UUID
  ) -> SupabaseMatchIngestService.MatchBundleRequest? {
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
      competitionId: nil,
      competitionName: nil,
      venueId: nil,
      venueName: nil,
      homeTeamId: nil,
      homeTeamName: match.homeTeam,
      awayTeamId: nil,
      awayTeamName: match.awayTeam,
      extraTimeEnabled: match.hasExtraTime,
      extraTimeHalfMinutes: match.hasExtraTime ? Int(match.extraTimeHalfLength / 60) : nil,
      penaltiesEnabled: match.hasPenalties,
      penaltyInitialRounds: match.penaltyInitialRounds,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      finalScore: makeFinalScorePayload(from: match),
      sourceDeviceId: record.sourceDeviceId ?? deviceIdProvider()
    )

    let periodSummaries = makePeriodSummaries(for: match, events: snapshot.events, finalHome: match.homeScore, finalAway: match.awayScore)
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
            awayScore: score.away
          )
        }
      )
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
        teamSide: supabaseTeamSide(for: event.team)
      )
    }

    return SupabaseMatchIngestService.MatchBundleRequest(
      match: matchPayload,
      periods: periods,
      events: events
    )
  }

  func makeFinalScorePayload(from match: Match) -> SupabaseMatchIngestService.MatchBundleRequest.FinalScorePayload {
    SupabaseMatchIngestService.MatchBundleRequest.FinalScorePayload(
      home: match.homeScore,
      away: match.awayScore,
      homeYellowCards: match.homeYellowCards,
      awayYellowCards: match.awayYellowCards,
      homeRedCards: match.homeRedCards,
      awayRedCards: match.awayRedCards,
      homeSubstitutions: match.homeSubs,
      awaySubstitutions: match.awaySubs
    )
  }

  func makePeriodSummaries(
    for match: Match,
    events: [MatchEventRecord],
    finalHome: Int,
    finalAway: Int
  ) -> [PeriodSummary] {
    let indices = periodIndices(from: events, match: match)
    var summaries: [PeriodSummary] = []
    for index in indices {
      let regulation = regulationSeconds(for: index, match: match)
      let periodEvents = events.filter { $0.period == index }
      let maxClock = periodEvents.map { clockSeconds(for: $0, match: match) }.max() ?? 0
      let added = max(0, maxClock - regulation)
      let partial = partialScore(upTo: index, events: events)
      summaries.append(PeriodSummary(index: index, regulationSeconds: regulation, addedTimeSeconds: added, partialScore: partial))
    }
    // Ensure summaries are sorted by index
    return summaries.sorted(by: { $0.index < $1.index })
  }

  func partialScore(upTo period: Int, events: [MatchEventRecord]) -> (home: Int, away: Int)? {
    guard period > 0 else { return nil }
    var home = 0
    var away = 0
    for event in events where event.period <= period {
      if case .goal(let details) = event.eventType {
        let scoringSide: TeamSide?
        if details.goalType == .ownGoal {
          scoringSide = event.team?.opponent
        } else {
          scoringSide = event.team
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

  func insertRemote(_ bundle: SupabaseMatchIngestService.RemoteMatchBundle, ownerUUID: UUID) throws -> CompletedMatchRecord? {
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
      payload: payload,
      remoteUpdatedAt: bundle.match.updatedAt,
      needsRemoteSync: false,
      lastSyncedAt: dateProvider(),
      sourceDeviceId: bundle.match.sourceDeviceId
    )
    return record
  }

  func merge(remote bundle: SupabaseMatchIngestService.RemoteMatchBundle, into record: CompletedMatchRecord) throws -> Data? {
    guard let snapshot = makeCompletedMatch(from: bundle) else { return nil }
    return try SwiftDataMatchHistoryStore.encode(snapshot)
  }

  func makeCompletedMatch(from bundle: SupabaseMatchIngestService.RemoteMatchBundle) -> CompletedMatch? {
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
      penaltyInitialRounds: remote.penaltyInitialRounds
    )
    match.startTime = remote.startedAt
    match.homeScore = remote.homeScore
    match.awayScore = remote.awayScore

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

    let events = bundle.events.compactMap { makeEvent(from: $0) }

    return CompletedMatch(
      id: remote.id,
      completedAt: remote.completedAt,
      match: match,
      events: events,
      ownerId: remote.ownerId.uuidString
    )
  }

  func makeEvent(from remote: SupabaseMatchIngestService.RemoteEvent) -> MatchEventRecord? {
    if let payload = remote.payload {
      return MatchEventRecord(
        id: remote.id,
        timestamp: payload.timestamp,
        actualTime: remote.occurredAt,
        matchTime: remote.matchTimeLabel,
        period: remote.periodIndex,
        eventType: payload.eventType,
        team: remote.teamSide.flatMap(domainTeamSide) ?? payload.team,
        details: payload.details
      )
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
      details: .general
    )
  }
}

// MARK: - Derived Helpers

private extension SupabaseMatchHistoryRepository {
  struct PeriodSummary {
    let index: Int
    let regulationSeconds: Int
    let addedTimeSeconds: Int
    let partialScore: (home: Int, away: Int)?
  }

  struct DerivedStats {
    let homeYellow: Int
    let awayYellow: Int
    let homeRed: Int
    let awayRed: Int
    let homeSubs: Int
    let awaySubs: Int
  }

  func deriveStats(from events: [SupabaseMatchIngestService.RemoteEvent]) -> DerivedStats {
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
      awaySubs: awaySubs
    )
  }

  func supabaseTeamSide(for team: TeamSide?) -> String? {
    guard let team else { return nil }
    switch team {
    case .home: return "home"
    case .away: return "away"
    }
  }

  func domainTeamSide(from value: String?) -> TeamSide? {
    guard let value else { return nil }
    switch value.lowercased() {
    case "home": return .home
    case "away": return .away
    default: return nil
    }
  }

  func supabaseEventType(for event: MatchEventRecord) -> String {
    switch event.eventType {
    case .goal:
      return "goal"
    case .card(let details):
      switch details.cardType {
      case .yellow: return "card_yellow"
      case .red: return "card_red"
      }
    case .substitution:
      return "substitution"
    case .kickOff:
      return "kick_off"
    case .periodStart:
      return "period_start"
    case .halfTime:
      return "half_time"
    case .periodEnd:
      return "period_end"
    case .matchEnd:
      return "match_end"
    case .penaltiesStart:
      return "penalties_start"
    case .penaltyAttempt:
      return "penalty_attempt"
    case .penaltiesEnd:
      return "penalties_end"
    }
  }

  func domainEventType(from supabaseType: String) -> MatchEventType? {
    switch supabaseType {
    case "goal":
      return .goal(GoalDetails(goalType: .regular, playerNumber: nil, playerName: nil))
    case "penalty_attempt":
      return .penaltyAttempt(PenaltyAttemptDetails(result: .missed, playerNumber: nil, round: 0))
    case "penalties_start":
      return .penaltiesStart
    case "penalties_end":
      return .penaltiesEnd
    case "kick_off":
      return .kickOff
    case "period_start":
      return .periodStart(1)
    case "period_end":
      return .periodEnd(1)
    case "half_time":
      return .halfTime
    case "match_end":
      return .matchEnd
    case "card_yellow":
      return .card(CardDetails(cardType: .yellow, recipientType: .player, playerNumber: nil, playerName: nil, officialRole: nil, reason: ""))
    case "card_red", "card_second_yellow":
      return .card(CardDetails(cardType: .red, recipientType: .player, playerNumber: nil, playerName: nil, officialRole: nil, reason: ""))
    case "substitution":
      return .substitution(SubstitutionDetails(playerOut: nil, playerIn: nil, playerOutName: nil, playerInName: nil))
    default:
      return nil
    }
  }

  func periodIndices(from events: [MatchEventRecord], match: Match) -> [Int] {
    let eventPeriods = Set(events.map { $0.period })
    if eventPeriods.isEmpty {
      return Array(1...max(1, match.numberOfPeriods))
    }
    return Array(eventPeriods).sorted()
  }

  func regulationSeconds(for period: Int, match: Match) -> Int {
    if period <= match.numberOfPeriods {
      let total = Int(match.duration)
      let periods = max(1, match.numberOfPeriods)
      return total / periods
    } else {
      return Int(match.extraTimeHalfLength)
    }
  }

  func clockSeconds(for event: MatchEventRecord, match: Match) -> Int {
    guard let total = totalSeconds(from: event.matchTime) else { return 0 }
    let prior = priorRegulationSeconds(before: event.period, match: match)
    return max(0, total - prior)
  }

  func priorRegulationSeconds(before period: Int, match: Match) -> Int {
    guard period > 1 else { return 0 }
    var total = 0
    for index in 1..<(period) {
      total += regulationSeconds(for: index, match: match)
    }
    return total
  }

  func totalSeconds(from label: String) -> Int? {
    let components = label.split(separator: ":")
    guard components.count == 2,
          let minutes = Int(components[0]),
          let seconds = Int(components[1]) else {
      return nil
    }
    return minutes * 60 + seconds
  }
}

private extension TeamSide {
  var opponent: TeamSide {
    switch self {
    case .home: return .away
    case .away: return .home
    }
  }
}
