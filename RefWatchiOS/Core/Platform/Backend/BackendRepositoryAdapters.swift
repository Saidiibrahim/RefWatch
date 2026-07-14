import Foundation
import RefWatchCore

/// Compatibility adapters that let the existing offline-first repositories keep their
/// domain contracts while all remote I/O moves to the authenticated Worker API.
struct BackendMatchRepositoryAPI: MatchRemoteServing {
  private let api: BackendMatchIngestService
  init(client: BackendAPIClient) { api = BackendMatchIngestService(client: client) }

  func ingestMatchBundle(_ request: MatchRemoteContract.MatchBundleRequest) async throws
    -> MatchRemoteContract.SyncResult
  {
    let result = try await api.ingest(request, idempotencyKey: request.match.id.uuidString)
    guard let id = UUID(uuidString: result.matchId) else { throw BackendAPIError.invalidResponse }
    return .init(matchId: id, updatedAt: result.updatedAt)
  }

  func fetchMatchBundles(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [MatchRemoteContract.RemoteMatchBundle]
  {
    let rows: [MatchBundleRow] = try await api.fetch(updatedAfter: updatedAfter)
    return rows.map { row in
      var match = row.match.remote
      match.deletedAt = row.match.deletedAt
      return .init(
        match: match,
        periods: row.periods.map(\.remote),
        events: row.events.map(\.remote),
        metrics: row.metrics?.remote)
    }
  }

  func deleteMatch(id: UUID) async throws { try await api.delete(id: id.uuidString) }
}

struct BackendScheduleRepositoryAPI: ScheduleRemoteServing {
  private let api: BackendScheduleAPI
  init(client: BackendAPIClient) { api = BackendScheduleAPI(client: client) }

  func fetchScheduledMatches(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [ScheduleRemoteContract.RemoteScheduledMatch]
  {
    let rows: [ScheduleRow] = try await api.fetch(updatedAfter: updatedAfter)
    return rows.map { row in
      .init(
        id: row.id, ownerId: row.ownerId, homeTeamName: row.homeTeamName,
        awayTeamName: row.awayTeamName, kickoffAt: row.kickoffAt,
        status: ScheduledMatch.Status(fromDatabase: row.status), competitionId: row.competitionId,
        competitionName: row.competitionName, venueId: row.venueId, venueName: row.venueName,
        homeTeamId: row.homeTeamId, awayTeamId: row.awayTeamId,
        homeMatchSheet: row.homeMatchSheet, awayMatchSheet: row.awayMatchSheet,
        notes: row.notes, sourceDeviceId: row.sourceDeviceId,
        createdAt: row.createdAt, updatedAt: row.updatedAt, deletedAt: row.deletedAt)
    }
  }

  func syncScheduledMatch(_ request: ScheduleRemoteContract.UpsertRequest) async throws
    -> ScheduleRemoteContract.SyncResult
  {
    let row: ScheduleRow = try await api.upsert(SchedulePayload(request))
    return .init(updatedAt: row.updatedAt)
  }

  func deleteScheduledMatch(id: UUID) async throws { try await api.delete(id: id.uuidString) }
}

struct BackendJournalRepositoryAPI: JournalRemoteServing {
  private let api: BackendJournalAPI
  init(client: BackendAPIClient) { api = BackendJournalAPI(client: client) }

  func fetchAssessments(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [JournalRemoteContract.RemoteAssessment]
  {
    let rows: [AssessmentRow] = try await api.fetchAssessments(updatedAfter: updatedAfter)
    return rows.compactMap { row in
      guard row.deletedAt == nil else { return nil }
      return .init(id: row.id, matchId: row.matchId, ownerId: row.ownerId, rating: row.rating,
      overall: row.overall, wentWell: row.wentWell, toImprove: row.toImprove,
      createdAt: row.createdAt, updatedAt: row.updatedAt)
    }
  }

  func syncAssessment(_ request: JournalRemoteContract.AssessmentRequest) async throws
    -> JournalRemoteContract.SyncResult
  {
    let row: AssessmentRow = try await api.upsertAssessment(AssessmentPayload(request))
    return .init(updatedAt: row.updatedAt)
  }

  func deleteAssessment(id: UUID) async throws { try await api.deleteAssessment(id: id.uuidString) }
}

struct BackendCompetitionRepositoryAPI: CompetitionRemoteServing {
  private let api: BackendLibraryAPI
  init(client: BackendAPIClient) { api = BackendLibraryAPI(client: client) }

  func fetchCompetitions(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [CompetitionRemoteContract.RemoteCompetition]
  {
    let rows: [CompetitionRow] = try await api.fetch(.competitions, updatedAfter: updatedAfter)
    return rows.map { .init(id: $0.id, ownerId: $0.ownerId,
      name: $0.name, level: $0.level, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
      deletedAt: $0.deletedAt) }
  }

  func syncCompetition(_ request: CompetitionRemoteContract.CompetitionRequest) async throws
    -> CompetitionRemoteContract.SyncResult
  {
    let row: CompetitionRow = try await api.upsert(.competitions, request: CompetitionPayload(request))
    return .init(updatedAt: row.updatedAt)
  }

  func deleteCompetition(competitionId: UUID) async throws {
    try await api.delete(.competitions, id: competitionId.uuidString)
  }
}

struct BackendVenueRepositoryAPI: VenueRemoteServing {
  private let api: BackendLibraryAPI
  init(client: BackendAPIClient) { api = BackendLibraryAPI(client: client) }

  func fetchVenues(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [VenueRemoteContract.RemoteVenue]
  {
    let rows: [VenueRow] = try await api.fetch(.venues, updatedAfter: updatedAfter)
    return rows.map { .init(id: $0.id, ownerId: $0.ownerId,
      name: $0.name, city: $0.city, country: $0.country,
      latitude: $0.latitude, longitude: $0.longitude,
      createdAt: $0.createdAt, updatedAt: $0.updatedAt, deletedAt: $0.deletedAt) }
  }

  func syncVenue(_ request: VenueRemoteContract.VenueRequest) async throws
    -> VenueRemoteContract.SyncResult
  {
    let row: VenueRow = try await api.upsert(.venues, request: VenuePayload(request))
    return .init(updatedAt: row.updatedAt)
  }

  func deleteVenue(venueId: UUID) async throws { try await api.delete(.venues, id: venueId.uuidString) }
}

struct BackendTeamRepositoryAPI: TeamRemoteServing {
  private let api: BackendLibraryAPI
  init(client: BackendAPIClient) { api = BackendLibraryAPI(client: client) }

  func fetchTeams(ownerId _: UUID, updatedAfter: Date?) async throws
    -> [TeamRemoteContract.RemoteTeam]
  {
    let rows: [TeamBundleRow] = try await api.fetch(.teams, updatedAfter: updatedAfter)
    return rows.map { row in
      .init(
        team: .init(id: row.team.id, ownerId: row.team.ownerId, name: row.team.name,
          shortName: row.team.shortName, division: row.team.division,
          primaryColorHex: row.team.colorPrimary, secondaryColorHex: row.team.colorSecondary,
          referenceKey: row.team.referenceKey, createdAt: row.team.createdAt, updatedAt: row.team.updatedAt,
          deletedAt: row.team.deletedAt),
        members: row.members.map { .init(id: $0.id, teamId: $0.teamId, displayName: $0.displayName,
          jerseyNumber: $0.jerseyNumber, role: $0.role, position: $0.position, notes: $0.notes, createdAt: $0.createdAt) },
        officials: row.officials.map { .init(id: $0.id, teamId: $0.teamId, displayName: $0.displayName,
          role: $0.role, phone: $0.phone, email: $0.email, createdAt: $0.createdAt) },
        tags: row.tags.map { .init(teamId: $0.teamId, value: $0.value) })
    }
  }

  func syncTeamBundle(_ request: TeamRemoteContract.TeamBundleRequest) async throws
    -> TeamRemoteContract.SyncResult
  {
    let result: UpdatedAtRow = try await api.upsert(.teams, request: TeamBundlePayload(request))
    return .init(updatedAt: result.updatedAt)
  }

  func importReferenceTeamsForCurrentUser(seasonYear _: Int, competitionCodes _: [String]?) async throws
    -> TeamRemoteContract.ReferenceTeamImportResult
  {
    throw BackendAPIError.validation(
      message: "Reference-team import is not available in the Worker API yet.",
      details: nil)
  }

  func deleteTeam(teamId: UUID) async throws { try await api.delete(.teams, id: teamId.uuidString) }
}

private struct ScheduleRow: Decodable {
  let id: UUID; let ownerId: UUID; let homeTeamName: String; let awayTeamName: String
  let kickoffAt: Date; let status: String; let competitionId: UUID?; let competitionName: String?
  let venueId: UUID?; let venueName: String?; let homeTeamId: UUID?; let awayTeamId: UUID?
  let homeMatchSheet: ScheduledMatchSheet?; let awayMatchSheet: ScheduledMatchSheet?
  let notes: String?; let sourceDeviceId: String?; let createdAt: Date; let updatedAt: Date
  let deletedAt: Date?
  enum CodingKeys: String, CodingKey {
    case id, status, notes
    case ownerId = "owner_id"; case homeTeamName = "home_team_name"; case awayTeamName = "away_team_name"
    case kickoffAt = "kickoff_at"; case competitionId = "competition_id"; case competitionName = "competition_name"
    case venueId = "venue_id"; case venueName = "venue_name"; case homeTeamId = "home_team_id"
    case awayTeamId = "away_team_id"; case homeMatchSheet = "home_match_sheet"; case awayMatchSheet = "away_match_sheet"
    case sourceDeviceId = "source_device_id"; case createdAt = "created_at"; case updatedAt = "updated_at"; case deletedAt = "deleted_at"
  }
}

private struct SchedulePayload: Encodable {
  let id: UUID; let homeTeamName: String; let awayTeamName: String; let kickoffAt: Date; let status: String
  let competitionId: UUID?; let competitionName: String?; let venueId: UUID?; let venueName: String?
  let homeTeamId: UUID?; let awayTeamId: UUID?; let homeMatchSheet: ScheduledMatchSheet?
  let awayMatchSheet: ScheduledMatchSheet?; let notes: String?; let sourceDeviceId: String?
  init(_ r: ScheduleRemoteContract.UpsertRequest) {
    id = r.id; homeTeamName = r.homeTeamName; awayTeamName = r.awayTeamName; kickoffAt = r.kickoffAt
    status = r.status.databaseValue; competitionId = r.competitionId; competitionName = r.competitionName
    venueId = r.venueId; venueName = r.venueName; homeTeamId = r.homeTeamId; awayTeamId = r.awayTeamId
    homeMatchSheet = r.homeMatchSheet?.normalized(); awayMatchSheet = r.awayMatchSheet?.normalized()
    notes = r.notes; sourceDeviceId = r.sourceDeviceId
  }
  enum CodingKeys: String, CodingKey {
    case id, status, notes
    case homeTeamName = "home_team_name"; case awayTeamName = "away_team_name"; case kickoffAt = "kickoff_at"
    case competitionId = "competition_id"; case competitionName = "competition_name"; case venueId = "venue_id"
    case venueName = "venue_name"; case homeTeamId = "home_team_id"; case awayTeamId = "away_team_id"
    case homeMatchSheet = "home_match_sheet"; case awayMatchSheet = "away_match_sheet"; case sourceDeviceId = "source_device_id"
  }
}

private struct AssessmentRow: Decodable {
  let id: UUID; let matchId: UUID; let ownerId: UUID; let rating: Int?; let overall: String?
  let wentWell: String?; let toImprove: String?; let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
  enum CodingKeys: String, CodingKey { case id, rating, overall; case matchId = "match_id"; case ownerId = "owner_id"; case wentWell = "went_well"; case toImprove = "to_improve"; case createdAt = "created_at"; case updatedAt = "updated_at"; case deletedAt = "deleted_at" }
}
private struct AssessmentPayload: Encodable {
  let id: UUID; let matchId: UUID; let rating: Int?; let overall: String?; let wentWell: String?; let toImprove: String?; let createdAt: Date
  init(_ r: JournalRemoteContract.AssessmentRequest) { id = r.id; matchId = r.matchId; rating = r.rating; overall = r.overall; wentWell = r.wentWell; toImprove = r.toImprove; createdAt = r.createdAt }
  enum CodingKeys: String, CodingKey { case id, rating, overall; case matchId = "match_id"; case wentWell = "went_well"; case toImprove = "to_improve"; case createdAt = "created_at" }
}
private struct CompetitionRow: Decodable { let id: UUID; let ownerId: UUID; let name: String; let level: String?; let createdAt: Date; let updatedAt: Date; let deletedAt: Date?; enum CodingKeys: String, CodingKey { case id, name, level; case ownerId = "owner_id"; case createdAt = "created_at"; case updatedAt = "updated_at"; case deletedAt = "deleted_at" } }
private struct CompetitionPayload: Encodable { let id: UUID; let name: String; let level: String?; init(_ r: CompetitionRemoteContract.CompetitionRequest) { id = r.id; name = r.name; level = r.level } }
private struct VenueRow: Decodable { let id: UUID; let ownerId: UUID; let name: String; let city: String?; let country: String?; let latitude: Double?; let longitude: Double?; let createdAt: Date; let updatedAt: Date; let deletedAt: Date?; enum CodingKeys: String, CodingKey { case id, name, city, country, latitude, longitude; case ownerId = "owner_id"; case createdAt = "created_at"; case updatedAt = "updated_at"; case deletedAt = "deleted_at" } }
private struct VenuePayload: Encodable { let id: UUID; let name: String; let city: String?; let country: String?; let latitude: Double?; let longitude: Double?; init(_ r: VenueRemoteContract.VenueRequest) { id = r.id; name = r.name; city = r.city; country = r.country; latitude = r.latitude; longitude = r.longitude } }

private struct TeamBundleRow: Decodable { let team: TeamRow; let members: [TeamMemberRow]; let officials: [TeamOfficialRow]; let tags: [TeamTagRow] }
private struct TeamRow: Decodable {
  let id: UUID; let ownerId: UUID; let name: String; let shortName: String?; let division: String?
  let colorPrimary: String?; let colorSecondary: String?; let referenceKey: String?
  let createdAt: Date; let updatedAt: Date; let deletedAt: Date?
  enum CodingKeys: String, CodingKey { case id, name, division; case ownerId = "owner_id"; case shortName = "short_name"; case colorPrimary = "color_primary"; case colorSecondary = "color_secondary"; case referenceKey = "reference_key"; case createdAt = "created_at"; case updatedAt = "updated_at"; case deletedAt = "deleted_at" }
}
private struct TeamMemberRow: Decodable { let id: UUID; let teamId: UUID; let displayName: String; let jerseyNumber: String?; let role: String?; let position: String?; let notes: String?; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, role, position, notes; case teamId = "team_id"; case displayName = "display_name"; case jerseyNumber = "jersey_number"; case createdAt = "created_at" } }
private struct TeamOfficialRow: Decodable { let id: UUID; let teamId: UUID; let displayName: String; let role: String; let phone: String?; let email: String?; let createdAt: Date; enum CodingKeys: String, CodingKey { case id, role, phone, email; case teamId = "team_id"; case displayName = "display_name"; case createdAt = "created_at" } }
private struct TeamTagRow: Decodable { let teamId: UUID; let value: String; enum CodingKeys: String, CodingKey { case value; case teamId = "team_id" } }
private struct UpdatedAtRow: Decodable { let updatedAt: Date; enum CodingKeys: String, CodingKey { case updatedAt = "updated_at" } }
private struct TeamBundlePayload: Encodable {
  struct Team: Encodable { let id: UUID; let name: String; let shortName: String?; let division: String?; let colorPrimary: String?; let colorSecondary: String?; let referenceKey: String?; enum CodingKeys: String, CodingKey { case id, name, division; case shortName = "short_name"; case colorPrimary = "color_primary"; case colorSecondary = "color_secondary"; case referenceKey = "reference_key" } }
  struct Member: Encodable { let id: UUID; let teamId: UUID; let displayName: String; let jerseyNumber: String?; let role: String?; let position: String?; let notes: String?; let createdAt: Date?; enum CodingKeys: String, CodingKey { case id, role, position, notes; case teamId = "team_id"; case displayName = "display_name"; case jerseyNumber = "jersey_number"; case createdAt = "created_at" } }
  struct Official: Encodable { let id: UUID; let teamId: UUID; let displayName: String; let role: String; let phone: String?; let email: String?; let createdAt: Date?; enum CodingKeys: String, CodingKey { case id, role, phone, email; case teamId = "team_id"; case displayName = "display_name"; case createdAt = "created_at" } }
  let team: Team; let members: [Member]; let officials: [Official]; let tags: [String]
  init(_ r: TeamRemoteContract.TeamBundleRequest) {
    team = .init(id: r.team.id, name: r.team.name, shortName: r.team.shortName, division: r.team.division, colorPrimary: r.team.primaryColorHex, colorSecondary: r.team.secondaryColorHex, referenceKey: r.team.referenceKey)
    members = r.members.map { .init(id: $0.id, teamId: $0.teamId, displayName: $0.displayName, jerseyNumber: $0.jerseyNumber, role: $0.role, position: $0.position, notes: $0.notes, createdAt: $0.createdAt) }
    officials = r.officials.map { .init(id: $0.id, teamId: $0.teamId, displayName: $0.displayName, role: $0.role, phone: $0.phone, email: $0.email, createdAt: $0.createdAt) }
    tags = r.tags
  }
}

private struct MatchBundleRow: Decodable {
  let match: MatchRow
  let periods: [PeriodRow]
  let events: [EventRow]
  let metrics: MetricsRow?
}

private struct MatchRow: Decodable {
  let id: UUID; let ownerId: UUID; let status: String; let startedAt: Date?; let completedAt: Date
  let durationSeconds: Int?; let numberOfPeriods: Int; let regulationMinutes: Int?; let halfTimeMinutes: Int?
  let competitionId: UUID?; let competitionName: String?; let venueId: UUID?; let venueName: String?
  let homeTeamId: UUID?; let homeTeamName: String; let awayTeamId: UUID?; let awayTeamName: String
  let extraTimeEnabled: Bool; let extraTimeHalfMinutes: Int?; let penaltiesEnabled: Bool
  let penaltyInitialRounds: Int; let homeScore: Int; let awayScore: Int
  let finalScore: MatchRemoteContract.MatchBundleRequest.FinalScorePayload?
  let sourceDeviceId: String?; let updatedAt: Date; let deletedAt: Date?
  enum CodingKeys: String, CodingKey {
    case id, status
    case ownerId = "owner_id"; case startedAt = "started_at"; case completedAt = "completed_at"
    case durationSeconds = "duration_seconds"; case numberOfPeriods = "number_of_periods"
    case regulationMinutes = "regulation_minutes"; case halfTimeMinutes = "half_time_minutes"
    case competitionId = "competition_id"; case competitionName = "competition_name"
    case venueId = "venue_id"; case venueName = "venue_name"; case homeTeamId = "home_team_id"
    case homeTeamName = "home_team_name"; case awayTeamId = "away_team_id"; case awayTeamName = "away_team_name"
    case extraTimeEnabled = "extra_time_enabled"; case extraTimeHalfMinutes = "extra_time_half_minutes"
    case penaltiesEnabled = "penalties_enabled"; case penaltyInitialRounds = "penalty_initial_rounds"
    case homeScore = "home_score"; case awayScore = "away_score"; case finalScore = "final_score"
    case sourceDeviceId = "source_device_id"; case updatedAt = "updated_at"; case deletedAt = "deleted_at"
  }
  var remote: MatchRemoteContract.RemoteMatch { .init(
    id: id, ownerId: ownerId, status: status, startedAt: startedAt, completedAt: completedAt,
    durationSeconds: durationSeconds, numberOfPeriods: numberOfPeriods, regulationMinutes: regulationMinutes,
    halfTimeMinutes: halfTimeMinutes, competitionId: competitionId, competitionName: competitionName,
    venueId: venueId, venueName: venueName, homeTeamId: homeTeamId, homeTeamName: homeTeamName,
    awayTeamId: awayTeamId, awayTeamName: awayTeamName, extraTimeEnabled: extraTimeEnabled,
    extraTimeHalfMinutes: extraTimeHalfMinutes, penaltiesEnabled: penaltiesEnabled,
    penaltyInitialRounds: penaltyInitialRounds, homeScore: homeScore, awayScore: awayScore,
    finalScore: finalScore, sourceDeviceId: sourceDeviceId, updatedAt: updatedAt) }
}

private struct PeriodRow: Decodable {
  let id: UUID; let matchId: UUID; let index: Int; let regulationSeconds: Int; let addedTimeSeconds: Int
  let result: MatchRemoteContract.MatchBundleRequest.PeriodResultPayload?
  enum CodingKeys: String, CodingKey { case id, index, result; case matchId = "match_id"; case regulationSeconds = "regulation_seconds"; case addedTimeSeconds = "added_time_seconds" }
  var remote: MatchRemoteContract.RemotePeriod { .init(id: id, matchId: matchId, index: index, regulationSeconds: regulationSeconds, addedTimeSeconds: addedTimeSeconds, result: result) }
}

private struct EventRow: Decodable {
  let id: UUID; let matchId: UUID; let occurredAt: Date; let periodIndex: Int; let clockSeconds: Int
  let matchTimeLabel: String; let eventType: String; let payload: MatchEventRecord?; let teamSide: String?
  let teamId: UUID?; let teamMemberId: UUID?
  enum CodingKeys: String, CodingKey { case id, payload; case matchId = "match_id"; case occurredAt = "occurred_at"; case periodIndex = "period_index"; case clockSeconds = "clock_seconds"; case matchTimeLabel = "match_time_label"; case eventType = "event_type"; case teamSide = "team_side"; case teamId = "team_id"; case teamMemberId = "team_member_id" }
  var remote: MatchRemoteContract.RemoteEvent { .init(id: id, matchId: matchId, occurredAt: occurredAt, periodIndex: periodIndex, clockSeconds: clockSeconds, matchTimeLabel: matchTimeLabel, eventType: eventType, payload: payload, teamSide: teamSide, teamId: teamId, teamMemberId: teamMemberId) }
}

private struct MetricsRow: Decodable {
  let matchId: UUID; let ownerId: UUID; let regulationMinutes: Int?; let halfTimeMinutes: Int?; let extraTimeMinutes: Int?
  let penaltiesEnabled: Bool; let totalGoals: Int; let totalCards: Int; let totalPenalties: Int; let yellowCards: Int
  let redCards: Int; let homeCards: Int; let awayCards: Int; let homeSubstitutions: Int; let awaySubstitutions: Int
  let penaltiesScored: Int; let penaltiesMissed: Int; let avgAddedTimeSeconds: Int; let generatedAt: Date
  enum CodingKeys: String, CodingKey { case matchId = "match_id"; case ownerId = "owner_id"; case regulationMinutes = "regulation_minutes"; case halfTimeMinutes = "half_time_minutes"; case extraTimeMinutes = "extra_time_minutes"; case penaltiesEnabled = "penalties_enabled"; case totalGoals = "total_goals"; case totalCards = "total_cards"; case totalPenalties = "total_penalties"; case yellowCards = "yellow_cards"; case redCards = "red_cards"; case homeCards = "home_cards"; case awayCards = "away_cards"; case homeSubstitutions = "home_substitutions"; case awaySubstitutions = "away_substitutions"; case penaltiesScored = "penalties_scored"; case penaltiesMissed = "penalties_missed"; case avgAddedTimeSeconds = "avg_added_time_seconds"; case generatedAt = "generated_at" }
  var remote: MatchRemoteContract.RemoteMetrics { .init(matchId: matchId, ownerId: ownerId, regulationMinutes: regulationMinutes, halfTimeMinutes: halfTimeMinutes, extraTimeMinutes: extraTimeMinutes, penaltiesEnabled: penaltiesEnabled, totalGoals: totalGoals, totalCards: totalCards, totalPenalties: totalPenalties, yellowCards: yellowCards, redCards: redCards, homeCards: homeCards, awayCards: awayCards, homeSubstitutions: homeSubstitutions, awaySubstitutions: awaySubstitutions, penaltiesScored: penaltiesScored, penaltiesMissed: penaltiesMissed, avgAddedTimeSeconds: avgAddedTimeSeconds, generatedAt: generatedAt) }
}
