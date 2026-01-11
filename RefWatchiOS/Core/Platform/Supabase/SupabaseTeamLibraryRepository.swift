//
//  SupabaseTeamLibraryRepository.swift
//  RefWatchiOS
//
//  Wraps the SwiftData team store with Supabase sync behaviour. Local changes
//  remain immediately available while the repository coordinates background
//  pushes and periodic pulls using the Supabase API.
//

import Combine
import Foundation
import OSLog
import RefWatchCore
import SwiftData

@MainActor
final class SupabaseTeamLibraryRepository: TeamLibraryStoring {
  private let store: SwiftDataTeamLibraryStore
  private let api: SupabaseTeamLibraryServing
  private let authStateProvider: SupabaseAuthStateProviding
  private let backlog: TeamLibrarySyncBacklogStoring
  private let metadataPersistor: TeamLibraryMetadataPersisting
  private let log = AppLog.supabase
  private let dateProvider: () -> Date

  private var authCancellable: AnyCancellable?
  private var ownerUUID: UUID?
  private var pendingPushes: Set<UUID> = []
  private var pendingDeletions: Set<UUID>
  private var processingTask: Task<Void, Never>?
  private var remoteCursor: Date?

  var changesPublisher: AnyPublisher<[TeamRecord], Never> {
    self.store.changesPublisher
  }

  init(
    store: SwiftDataTeamLibraryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseTeamLibraryServing,
    backlog: TeamLibrarySyncBacklogStoring,
    metadataPersistor: TeamLibraryMetadataPersisting? = nil,
    dateProvider: @escaping () -> Date = Date.init)
  {
    self.store = store
    self.authStateProvider = authStateProvider
    self.api = api
    self.backlog = backlog
    self.metadataPersistor = metadataPersistor ?? store
    self.dateProvider = dateProvider
    self.pendingDeletions = backlog.loadPendingDeletionIDs()
    publishSyncStatus()

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
  }

  // MARK: - TeamLibraryStoring

  func loadAllTeams() throws -> [TeamRecord] { try self.store.loadAllTeams() }

  func searchTeams(query: String) throws -> [TeamRecord] { try self.store.searchTeams(query: query) }

  func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord {
    let team = try store.createTeam(name: name, shortName: shortName, division: division)
    applyOwnerIdentityIfNeeded(to: team)
    try self.metadataPersistor.persistMetadataChanges(for: team)
    enqueuePush(for: team.id)
    return team
  }

  func updateTeam(_ team: TeamRecord) throws {
    try self.store.updateTeam(team)
    applyOwnerIdentityIfNeeded(to: team)
    enqueuePush(for: team.id)
  }

  func deleteTeam(_ team: TeamRecord) throws {
    let teamId = team.id
    try self.store.deleteTeam(team)
    self.pendingPushes.remove(teamId)
    self.pendingDeletions.insert(teamId)
    self.backlog.addPendingDeletion(id: teamId)
    scheduleProcessingTask()
    publishSyncStatus()
  }

  func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
    let player = try store.addPlayer(to: team, name: name, number: number)
    enqueuePush(for: team.id)
    return player
  }

  func updatePlayer(_ player: PlayerRecord) throws {
    try self.store.updatePlayer(player)
    if let teamId = player.team?.id {
      enqueuePush(for: teamId)
    }
  }

  func deletePlayer(_ player: PlayerRecord) throws {
    let teamId = player.team?.id
    try self.store.deletePlayer(player)
    if let teamId {
      enqueuePush(for: teamId)
    }
  }

  func addOfficial(to team: TeamRecord, name: String, roleRaw: String) throws -> TeamOfficialRecord {
    let official = try store.addOfficial(to: team, name: name, roleRaw: roleRaw)
    enqueuePush(for: team.id)
    return official
  }

  func updateOfficial(_ official: TeamOfficialRecord) throws {
    try self.store.updateOfficial(official)
    if let teamId = official.team?.id {
      enqueuePush(for: teamId)
    }
  }

  func deleteOfficial(_ official: TeamOfficialRecord) throws {
    let teamId = official.team?.id
    try self.store.deleteOfficial(official)
    if let teamId {
      enqueuePush(for: teamId)
    }
  }

  func refreshFromRemote() async throws {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: "refresh team library")
    }
    do {
      try await flushPendingDeletions()
      try await pushDirtyTeams()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      self.log.error("Team library refresh failed: \(error.localizedDescription, privacy: .public)")
      throw error
    }
  }
}

// MARK: - Identity Handling & Sync Scheduling

extension SupabaseTeamLibraryRepository {
  private func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      self.ownerUUID = nil
      self.remoteCursor = nil
      self.processingTask?.cancel()
      self.processingTask = nil
      self.pendingPushes.removeAll()
      self.pendingDeletions.removeAll()
      self.backlog.clearAll()
      do {
        try self.store.wipeAllForLogout()
        self.log.notice("Cleared team library cache after sign-out")
      } catch {
        self.log.error("Failed to wipe team library on sign-out: \(error.localizedDescription, privacy: .public)")
      }
      publishSyncStatus()
    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        self.log.error("Supabase auth linked with non-UUID id: \(userId, privacy: .public)")
        return
      }
      self.ownerUUID = uuid
      publishSyncStatus()
      self.scheduleInitialSync()
    }
  }

  private func scheduleInitialSync() {
    self.scheduleProcessingTask()
    Task { [weak self] in
      await self?.performInitialPull()
    }
  }

  private func performInitialPull() async {
    guard let ownerUUID else { return }
    do {
      try await flushPendingDeletions()
      try await pushDirtyTeams()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      self.log.error("Initial team sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func enqueuePush(for teamId: UUID) {
    self.pendingPushes.insert(teamId)
    applyOwnerIdentityIfNeeded(forTeamId: teamId)
    self.scheduleProcessingTask()
    publishSyncStatus()
  }

  private func scheduleProcessingTask() {
    guard self.processingTask == nil else { return }
    self.processingTask = Task { [weak self] in
      await self?.drainQueues()
    }
  }

  private func drainQueues() async {
    defer {
      Task { @MainActor in self.processingTask = nil }
    }

    while true {
      guard let operation = await nextOperation() else { return }
      switch operation {
      case let .delete(teamId):
        await performRemoteDeletion(teamId: teamId)
      case let .push(teamId):
        await performRemotePush(teamId: teamId)
      }
    }
  }

  fileprivate enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  private func nextOperation() async -> SyncOperation? {
    await MainActor.run {
      guard self.ownerUUID != nil else { return nil }
      if let deletionId = pendingDeletions.popFirst() {
        return .delete(deletionId)
      }
      if let pushId = pendingPushes.popFirst() {
        return .push(pushId)
      }
      return nil
    }
  }
}

extension SupabaseTeamLibraryRepository: AggregateTeamApplying {
  func upsertTeam(from aggregate: AggregateSnapshotPayload.Team) throws {
    let ownerUUID = try requireOwnerUUIDForAggregate(operation: "aggregate team upsert")
    let record = try store.upsertFromAggregate(aggregate, ownerSupabaseId: ownerUUID.uuidString)
    self.pendingDeletions.remove(record.id)
    self.backlog.removePendingDeletion(id: record.id)
    self.enqueuePush(for: record.id)
  }

  func deleteTeam(id: UUID) throws {
    _ = try requireOwnerUUIDForAggregate(operation: "aggregate team delete")
    if let existing = try fetchTeam(with: id) {
      try self.deleteTeam(existing)
    } else {
      self.pendingPushes.remove(id)
      self.pendingDeletions.insert(id)
      self.backlog.addPendingDeletion(id: id)
      self.scheduleProcessingTask()
      publishSyncStatus()
    }
  }
}

// MARK: - Remote Operations

extension SupabaseTeamLibraryRepository {
  private func flushPendingDeletions() async throws {
    guard self.ownerUUID != nil else { return }
    while let deletionId = pendingDeletions.popFirst() {
      await self.performRemoteDeletion(teamId: deletionId)
    }
  }

  private func performRemoteDeletion(teamId: UUID) async {
    do {
      try await self.api.deleteTeam(teamId: teamId)
      self.backlog.removePendingDeletion(id: teamId)
    } catch {
      self.pendingDeletions.insert(teamId)
      self.log.error(
        "Supabase team delete failed id=\(teamId.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      reportTeamSyncFailure(error, phase: .delete, teamId: teamId)
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    publishSyncStatus()
  }

  private func performRemotePush(teamId: UUID) async {
    guard let ownerUUID else { return }
    guard let team = try? fetchTeam(with: teamId) else { return }
    guard team.needsRemoteSync else { return }

    let bundle = makeBundleRequest(for: team, ownerUUID: ownerUUID)

    do {
      let syncResult = try await api.syncTeamBundle(bundle)
      team.applyRemoteSyncMetadata(
        ownerId: ownerUUID.uuidString,
        remoteUpdatedAt: syncResult.updatedAt,
        synchronizedAt: self.dateProvider())
      try self.metadataPersistor.persistMetadataChanges(for: team)
      self.remoteCursor = max(self.remoteCursor ?? syncResult.updatedAt, syncResult.updatedAt)
      self.store.publishChanges()
    } catch {
      self.pendingPushes.insert(teamId)
      self.log.error(
        "Supabase team push failed id=\(teamId.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      reportTeamSyncFailure(error, phase: .push, teamId: teamId)
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    publishSyncStatus()
  }

  private func pushDirtyTeams() async throws {
    guard let ownerUUID else { return }
    let teams = try store.loadAllTeams().filter(\.needsRemoteSync)
    for team in teams {
      self.pendingPushes.insert(team.id)
    }
    guard self.pendingPushes.isEmpty == false else { return }
    self.scheduleProcessingTask()
    publishSyncStatus()
    // Wait briefly for processing to drain
    try? await Task.sleep(nanoseconds: 100_000_000)
    try await self.pullRemoteUpdates(for: ownerUUID)
  }

  private func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let remoteTeams = try await api.fetchTeams(ownerId: ownerUUID, updatedAfter: self.remoteCursor)
    guard remoteTeams.isEmpty == false else { return }
    let filtered = remoteTeams.filter { !self.pendingDeletions.contains($0.team.id) }
    guard filtered.isEmpty == false else { return }
    try mergeRemoteTeams(filtered, ownerUUID: ownerUUID)
    if let maxDate = filtered.map(\.team.updatedAt).max() {
      self.remoteCursor = max(self.remoteCursor ?? maxDate, maxDate)
    }
    publishSyncStatus()
  }
}

// MARK: - Local Merge Helpers

extension SupabaseTeamLibraryRepository {
  private func fetchTeam(with id: UUID) throws -> TeamRecord? {
    let descriptor = FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.id == id })
    return try self.store.context.fetch(descriptor).first
  }

  private func requireOwnerUUIDForAggregate(operation: String) throws -> UUID {
    guard let ownerUUID else {
      throw PersistenceAuthError.signedOut(operation: operation)
    }
    return ownerUUID
  }

  private func mergeRemoteTeams(_ remoteTeams: [SupabaseTeamLibraryAPI.RemoteTeam], ownerUUID: UUID) throws {
    var didChange = false
    for remote in remoteTeams {
      if let existing = try fetchTeam(with: remote.team.id) {
        let remoteUpdatedAt = remote.team.updatedAt
        let currentRemote = existing.remoteUpdatedAt ?? .distantPast
        if remoteUpdatedAt <= currentRemote, existing.needsRemoteSync == false {
          continue
        }
        self.apply(remote: remote, to: existing, ownerUUID: ownerUUID)
        didChange = true
      } else {
        try self.insertRemoteTeam(remote, ownerUUID: ownerUUID)
        didChange = true
      }
    }
    if didChange {
      try self.store.context.save()
      self.store.publishChanges()
    }
  }

  private func insertRemoteTeam(_ remote: SupabaseTeamLibraryAPI.RemoteTeam, ownerUUID: UUID) throws {
    let team = TeamRecord(
      id: remote.team.id,
      name: remote.team.name,
      shortName: remote.team.shortName,
      division: remote.team.division,
      primaryColorHex: remote.team.primaryColorHex,
      secondaryColorHex: remote.team.secondaryColorHex,
      ownerSupabaseId: remote.team.ownerId.uuidString,
      lastModifiedAt: remote.team.updatedAt,
      remoteUpdatedAt: remote.team.updatedAt,
      needsRemoteSync: false)

    for member in remote.members {
      let player = PlayerRecord(
        id: member.id,
        name: member.displayName,
        number: Int(member.jerseyNumber ?? ""),
        position: member.position,
        notes: member.notes,
        team: team)
      team.players.append(player)
      self.store.context.insert(player)
    }

    for official in remote.officials {
      let record = TeamOfficialRecord(
        id: official.id,
        name: official.displayName,
        roleRaw: official.role,
        phone: official.phone,
        email: official.email,
        team: team)
      team.officials.append(record)
      self.store.context.insert(record)
    }

    self.store.context.insert(team)
  }

  private func apply(remote: SupabaseTeamLibraryAPI.RemoteTeam, to team: TeamRecord, ownerUUID: UUID) {
    team.name = remote.team.name
    team.shortName = remote.team.shortName
    team.division = remote.team.division
    team.primaryColorHex = remote.team.primaryColorHex
    team.secondaryColorHex = remote.team.secondaryColorHex
    team.ownerSupabaseId = remote.team.ownerId.uuidString

    let existingPlayers = Dictionary(uniqueKeysWithValues: team.players.map { ($0.id, $0) })
    var retainedPlayers: [UUID: PlayerRecord] = [:]

    for member in remote.members {
      if let local = existingPlayers[member.id] {
        local.name = member.displayName
        local.number = Int(member.jerseyNumber ?? "")
        local.position = member.position
        local.notes = member.notes
        retainedPlayers[member.id] = local
      } else {
        let player = PlayerRecord(
          id: member.id,
          name: member.displayName,
          number: Int(member.jerseyNumber ?? ""),
          position: member.position,
          notes: member.notes,
          team: team)
        team.players.append(player)
        self.store.context.insert(player)
        retainedPlayers[member.id] = player
      }
    }

    team.players.removeAll { player in
      if retainedPlayers[player.id] != nil {
        return false
      }
      self.store.context.delete(player)
      return true
    }

    let existingOfficials = Dictionary(uniqueKeysWithValues: team.officials.map { ($0.id, $0) })
    var retainedOfficials: [UUID: TeamOfficialRecord] = [:]

    for official in remote.officials {
      if let local = existingOfficials[official.id] {
        local.name = official.displayName
        local.roleRaw = official.role
        local.phone = official.phone
        local.email = official.email
        retainedOfficials[official.id] = local
      } else {
        let record = TeamOfficialRecord(
          id: official.id,
          name: official.displayName,
          roleRaw: official.role,
          phone: official.phone,
          email: official.email,
          team: team)
        team.officials.append(record)
        self.store.context.insert(record)
        retainedOfficials[official.id] = record
      }
    }

    team.officials.removeAll { official in
      if retainedOfficials[official.id] != nil {
        return false
      }
      self.store.context.delete(official)
      return true
    }

    team.applyRemoteSyncMetadata(
      ownerId: ownerUUID.uuidString,
      remoteUpdatedAt: remote.team.updatedAt,
      synchronizedAt: self.dateProvider())
  }

  private func applyOwnerIdentityIfNeeded(to team: TeamRecord) {
    guard let ownerUUID else { return }
    if team.ownerSupabaseId != ownerUUID.uuidString {
      team.ownerSupabaseId = ownerUUID.uuidString
    }
  }

  private func applyOwnerIdentityIfNeeded(forTeamId teamId: UUID) {
    guard let ownerUUID else { return }
    if let team = try? fetchTeam(with: teamId), team.ownerSupabaseId != ownerUUID.uuidString {
      team.ownerSupabaseId = ownerUUID.uuidString
      try? self.metadataPersistor.persistMetadataChanges(for: team)
    }
  }

  private func makeBundleRequest(for team: TeamRecord, ownerUUID: UUID) -> SupabaseTeamLibraryAPI.TeamBundleRequest {
    let teamInput = SupabaseTeamLibraryAPI.TeamInput(
      id: team.id,
      ownerId: ownerUUID,
      name: team.name,
      shortName: team.shortName,
      division: team.division,
      primaryColorHex: team.primaryColorHex,
      secondaryColorHex: team.secondaryColorHex)

    let memberInputs: [SupabaseTeamLibraryAPI.MemberInput] = team.players.map { player in
      SupabaseTeamLibraryAPI.MemberInput(
        id: player.id,
        teamId: team.id,
        displayName: player.name,
        jerseyNumber: player.number.map(String.init),
        role: nil,
        position: player.position,
        notes: player.notes,
        createdAt: nil)
    }

    let officialInputs: [SupabaseTeamLibraryAPI.OfficialInput] = team.officials.map { official in
      SupabaseTeamLibraryAPI.OfficialInput(
        id: official.id,
        teamId: team.id,
        displayName: official.name,
        role: official.roleRaw,
        phone: official.phone,
        email: official.email,
        createdAt: nil)
    }

    return SupabaseTeamLibraryAPI.TeamBundleRequest(
      team: teamInput,
      members: memberInputs,
      officials: officialInputs,
      tags: [])
  }

  private func publishSyncStatus() {
    let info: [String: Any] = [
      "component": "team_library",
      "pendingPushes": pendingPushes.count,
      "pendingDeletions": self.pendingDeletions.count,
      "signedIn": self.ownerUUID != nil,
      "timestamp": self.dateProvider(),
    ]
    NotificationCenter.default.post(name: .syncStatusUpdate, object: nil, userInfo: info)
  }

  fileprivate enum TeamSyncPhase { case push, delete }

  private func reportTeamSyncFailure(_ error: Error, phase: TeamSyncPhase, teamId: UUID) {
    let description = String(describing: error)
    let phaseLabel = phase == .push ? "sync" : "delete"
    let message = "Supabase team \(phaseLabel) failed: \(description)"
    let contextSuffix = self.containsHTTPStatus(error, code: 404) ? ".404" : ""
    let context = "team_library.\(phaseLabel)\(contextSuffix)"

    NotificationCenter.default.post(
      name: .syncNonrecoverableError,
      object: nil,
      userInfo: [
        "error": "\(message) [team_id=\(teamId.uuidString)]",
        "context": context,
      ])
  }

  private func containsHTTPStatus(_ error: Error, code: Int) -> Bool {
    let nsError = error as NSError
    if nsError.code == code { return true }
    let description = String(describing: error)
    return description.contains("\(code)")
  }
}
