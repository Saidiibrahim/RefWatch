//
//  SupabaseTeamLibraryRepository.swift
//  RefZoneiOS
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

  init(
    store: SwiftDataTeamLibraryStore,
    authStateProvider: SupabaseAuthStateProviding,
    api: SupabaseTeamLibraryServing = SupabaseTeamLibraryAPI(),
    backlog: TeamLibrarySyncBacklogStoring = SupabaseTeamSyncBacklogStore(),
    metadataPersistor: TeamLibraryMetadataPersisting? = nil,
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.store = store
    self.authStateProvider = authStateProvider
    self.api = api
    self.backlog = backlog
    self.metadataPersistor = metadataPersistor ?? store
    self.dateProvider = dateProvider
    self.pendingDeletions = backlog.loadPendingDeletionIDs()

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
  }

  // MARK: - TeamLibraryStoring

  func loadAllTeams() throws -> [TeamRecord] { try store.loadAllTeams() }

  func searchTeams(query: String) throws -> [TeamRecord] { try store.searchTeams(query: query) }

  func createTeam(name: String, shortName: String?, division: String?) throws -> TeamRecord {
    let team = try store.createTeam(name: name, shortName: shortName, division: division)
    applyOwnerIdentityIfNeeded(to: team)
    try metadataPersistor.persistMetadataChanges(for: team)
    enqueuePush(for: team.id)
    return team
  }

  func updateTeam(_ team: TeamRecord) throws {
    try store.updateTeam(team)
    applyOwnerIdentityIfNeeded(to: team)
    enqueuePush(for: team.id)
  }

  func deleteTeam(_ team: TeamRecord) throws {
    let teamId = team.id
    try store.deleteTeam(team)
    pendingPushes.remove(teamId)
    pendingDeletions.insert(teamId)
    backlog.addPendingDeletion(id: teamId)
    scheduleProcessingTask()
  }

  func addPlayer(to team: TeamRecord, name: String, number: Int?) throws -> PlayerRecord {
    let player = try store.addPlayer(to: team, name: name, number: number)
    enqueuePush(for: team.id)
    return player
  }

  func updatePlayer(_ player: PlayerRecord) throws {
    try store.updatePlayer(player)
    if let teamId = player.team?.id {
      enqueuePush(for: teamId)
    }
  }

  func deletePlayer(_ player: PlayerRecord) throws {
    let teamId = player.team?.id
    try store.deletePlayer(player)
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
    try store.updateOfficial(official)
    if let teamId = official.team?.id {
      enqueuePush(for: teamId)
    }
  }

  func deleteOfficial(_ official: TeamOfficialRecord) throws {
    let teamId = official.team?.id
    try store.deleteOfficial(official)
    if let teamId {
      enqueuePush(for: teamId)
    }
  }
 }

// MARK: - Identity Handling & Sync Scheduling

private extension SupabaseTeamLibraryRepository {
  func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
      ownerUUID = nil
      remoteCursor = nil
    case let .signedIn(userId, _, _):
      guard let uuid = UUID(uuidString: userId) else {
        log.error("Supabase auth linked with non-UUID id: \(userId, privacy: .public)")
        return
      }
      ownerUUID = uuid
      scheduleInitialSync()
    }
  }

  func scheduleInitialSync() {
    scheduleProcessingTask()
    Task { [weak self] in
      await self?.performInitialPull()
    }
  }

  func performInitialPull() async {
    guard let ownerUUID else { return }
    do {
      try await flushPendingDeletions()
      try await pushDirtyTeams()
      try await pullRemoteUpdates(for: ownerUUID)
    } catch {
      log.error("Initial team sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func enqueuePush(for teamId: UUID) {
    pendingPushes.insert(teamId)
    applyOwnerIdentityIfNeeded(forTeamId: teamId)
    scheduleProcessingTask()
  }

  func scheduleProcessingTask() {
    guard processingTask == nil else { return }
    processingTask = Task { [weak self] in
      await self?.drainQueues()
    }
  }

  func drainQueues() async {
    defer {
      Task { @MainActor in self.processingTask = nil }
    }

    while true {
      guard let operation = await nextOperation() else { return }
      switch operation {
      case .delete(let teamId):
        await performRemoteDeletion(teamId: teamId)
      case .push(let teamId):
        await performRemotePush(teamId: teamId)
      }
    }
  }

  enum SyncOperation {
    case push(UUID)
    case delete(UUID)
  }

  func nextOperation() async -> SyncOperation? {
    await MainActor.run {
      guard ownerUUID != nil else { return nil }
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

// MARK: - Remote Operations

private extension SupabaseTeamLibraryRepository {
  func flushPendingDeletions() async throws {
    guard ownerUUID != nil else { return }
    while let deletionId = pendingDeletions.popFirst() {
      await performRemoteDeletion(teamId: deletionId)
    }
  }

  func performRemoteDeletion(teamId: UUID) async {
    do {
      try await api.deleteTeam(teamId: teamId)
      backlog.removePendingDeletion(id: teamId)
    } catch {
      pendingDeletions.insert(teamId)
      log.error("Supabase team delete failed id=\(teamId.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func performRemotePush(teamId: UUID) async {
    guard let ownerUUID else { return }
    guard let team = try? fetchTeam(with: teamId) else { return }
    guard team.needsRemoteSync else { return }

    let bundle = makeBundleRequest(for: team, ownerUUID: ownerUUID)

    do {
      let syncResult = try await api.syncTeamBundle(bundle)
      team.applyRemoteSyncMetadata(
        ownerId: ownerUUID.uuidString,
        remoteUpdatedAt: syncResult.updatedAt,
        synchronizedAt: dateProvider()
      )
      try metadataPersistor.persistMetadataChanges(for: team)
      remoteCursor = max(remoteCursor ?? syncResult.updatedAt, syncResult.updatedAt)
    } catch {
      pendingPushes.insert(teamId)
      log.error("Supabase team push failed id=\(teamId.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
      try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
  }

  func pushDirtyTeams() async throws {
    guard let ownerUUID else { return }
    let teams = try store.loadAllTeams().filter { $0.needsRemoteSync }
    for team in teams {
      pendingPushes.insert(team.id)
    }
    guard pendingPushes.isEmpty == false else { return }
    scheduleProcessingTask()
    // Wait briefly for processing to drain
    try? await Task.sleep(nanoseconds: 100_000_000)
    try await pullRemoteUpdates(for: ownerUUID)
  }

  func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let remoteTeams = try await api.fetchTeams(ownerId: ownerUUID, updatedAfter: remoteCursor)
    guard remoteTeams.isEmpty == false else { return }
    let filtered = remoteTeams.filter { !pendingDeletions.contains($0.team.id) }
    guard filtered.isEmpty == false else { return }
    try mergeRemoteTeams(filtered, ownerUUID: ownerUUID)
    if let maxDate = filtered.map({ $0.team.updatedAt }).max() {
      remoteCursor = max(remoteCursor ?? maxDate, maxDate)
    }
  }
}

// MARK: - Local Merge Helpers

private extension SupabaseTeamLibraryRepository {
  func fetchTeam(with id: UUID) throws -> TeamRecord? {
    let descriptor = FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.id == id })
    return try store.context.fetch(descriptor).first
  }

  func mergeRemoteTeams(_ remoteTeams: [SupabaseTeamLibraryAPI.RemoteTeam], ownerUUID: UUID) throws {
    var didChange = false
    for remote in remoteTeams {
      if let existing = try fetchTeam(with: remote.team.id) {
        let remoteUpdatedAt = remote.team.updatedAt
        let currentRemote = existing.remoteUpdatedAt ?? .distantPast
        if remoteUpdatedAt <= currentRemote && existing.needsRemoteSync == false {
          continue
        }
        apply(remote: remote, to: existing, ownerUUID: ownerUUID)
        didChange = true
      } else {
        try insertRemoteTeam(remote, ownerUUID: ownerUUID)
        didChange = true
      }
    }
    if didChange {
      try store.context.save()
    }
  }

  func insertRemoteTeam(_ remote: SupabaseTeamLibraryAPI.RemoteTeam, ownerUUID: UUID) throws {
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
      needsRemoteSync: false
    )

    for member in remote.members {
      let player = PlayerRecord(
        id: member.id,
        name: member.displayName,
        number: Int(member.jerseyNumber ?? ""),
        position: member.position,
        notes: member.notes,
        team: team
      )
      team.players.append(player)
      store.context.insert(player)
    }

    for official in remote.officials {
      let record = TeamOfficialRecord(
        id: official.id,
        name: official.displayName,
        roleRaw: official.role,
        phone: official.phone,
        email: official.email,
        team: team
      )
      team.officials.append(record)
      store.context.insert(record)
    }

    store.context.insert(team)
  }

  func apply(remote: SupabaseTeamLibraryAPI.RemoteTeam, to team: TeamRecord, ownerUUID: UUID) {
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
          team: team
        )
        team.players.append(player)
        store.context.insert(player)
        retainedPlayers[member.id] = player
      }
    }

    team.players.removeAll { player in
      if retainedPlayers[player.id] != nil {
        return false
      }
      store.context.delete(player)
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
          team: team
        )
        team.officials.append(record)
        store.context.insert(record)
        retainedOfficials[official.id] = record
      }
    }

    team.officials.removeAll { official in
      if retainedOfficials[official.id] != nil {
        return false
      }
      store.context.delete(official)
      return true
    }

    team.applyRemoteSyncMetadata(
      ownerId: ownerUUID.uuidString,
      remoteUpdatedAt: remote.team.updatedAt,
      synchronizedAt: dateProvider()
    )
  }

  func applyOwnerIdentityIfNeeded(to team: TeamRecord) {
    guard let ownerUUID else { return }
    if team.ownerSupabaseId != ownerUUID.uuidString {
      team.ownerSupabaseId = ownerUUID.uuidString
    }
  }

  func applyOwnerIdentityIfNeeded(forTeamId teamId: UUID) {
    guard let ownerUUID else { return }
    if let team = try? fetchTeam(with: teamId), team.ownerSupabaseId != ownerUUID.uuidString {
      team.ownerSupabaseId = ownerUUID.uuidString
      try? metadataPersistor.persistMetadataChanges(for: team)
    }
  }

  func makeBundleRequest(for team: TeamRecord, ownerUUID: UUID) -> SupabaseTeamLibraryAPI.TeamBundleRequest {
    let teamInput = SupabaseTeamLibraryAPI.TeamInput(
      id: team.id,
      ownerId: ownerUUID,
      name: team.name,
      shortName: team.shortName,
      division: team.division,
      primaryColorHex: team.primaryColorHex,
      secondaryColorHex: team.secondaryColorHex
    )

    let memberInputs: [SupabaseTeamLibraryAPI.MemberInput] = team.players.map { player in
      SupabaseTeamLibraryAPI.MemberInput(
        id: player.id,
        teamId: team.id,
        displayName: player.name,
        jerseyNumber: player.number.map(String.init),
        role: nil,
        position: player.position,
        notes: player.notes,
        createdAt: nil
      )
    }

    let officialInputs: [SupabaseTeamLibraryAPI.OfficialInput] = team.officials.map { official in
      SupabaseTeamLibraryAPI.OfficialInput(
        id: official.id,
        teamId: team.id,
        displayName: official.name,
        role: official.roleRaw,
        phone: official.phone,
        email: official.email,
        createdAt: nil
      )
    }

    return SupabaseTeamLibraryAPI.TeamBundleRequest(
      team: teamInput,
      members: memberInputs,
      officials: officialInputs,
      tags: []
    )
  }
}
