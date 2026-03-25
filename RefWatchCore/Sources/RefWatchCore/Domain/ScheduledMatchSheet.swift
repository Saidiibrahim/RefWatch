//
//  ScheduledMatchSheet.swift
//  RefWatchCore
//
//  Frozen schedule-owned match sheet models shared by iPhone and watch.
//

import Foundation

/// Persistence status for a schedule-owned match sheet.
public enum ScheduledMatchSheetStatus: String, Codable, CaseIterable, Hashable, Sendable {
  case draft
  case ready

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = Self(rawValue: rawValue) ?? .draft
  }
}

/// Category for non-player match-sheet members.
public enum MatchSheetStaffCategory: String, Codable, CaseIterable, Hashable, Sendable {
  case staff
  case otherMember

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self = Self(rawValue: rawValue) ?? .staff
  }
}

/// Frozen player snapshot stored on a scheduled match sheet.
public struct MatchSheetPlayerEntry: Identifiable, Codable, Hashable, Sendable {
  public let entryId: UUID
  public var sourcePlayerId: UUID?
  public var displayName: String
  public var shirtNumber: Int?
  public var position: String?
  public var notes: String?
  public var sortOrder: Int

  public var id: UUID { self.entryId }

  public init(
    entryId: UUID = UUID(),
    sourcePlayerId: UUID? = nil,
    displayName: String,
    shirtNumber: Int? = nil,
    position: String? = nil,
    notes: String? = nil,
    sortOrder: Int)
  {
    self.entryId = entryId
    self.sourcePlayerId = sourcePlayerId
    self.displayName = displayName
    self.shirtNumber = shirtNumber
    self.position = position
    self.notes = notes
    self.sortOrder = sortOrder
  }

  enum CodingKeys: String, CodingKey {
    case entryId
    case sourcePlayerId
    case displayName
    case shirtNumber
    case position
    case notes
    case sortOrder
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.entryId = try container.decodeIfPresent(UUID.self, forKey: .entryId) ?? UUID()
    self.sourcePlayerId = try container.decodeIfPresent(UUID.self, forKey: .sourcePlayerId)
    self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    self.shirtNumber = try container.decodeIfPresent(Int.self, forKey: .shirtNumber)
    self.position = try container.decodeIfPresent(String.self, forKey: .position)
    self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    self.sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
  }

  /// Returns whether the entry contains the denormalized display fields needed
  /// to stand alone after the source library roster changes.
  public var hasRequiredDisplayFields: Bool {
    self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  public func normalized() -> MatchSheetPlayerEntry {
    MatchSheetPlayerEntry(
      entryId: self.entryId,
      sourcePlayerId: self.sourcePlayerId,
      displayName: self.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      shirtNumber: self.shirtNumber,
      position: self.position?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      notes: self.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      sortOrder: self.sortOrder)
  }
}

/// Frozen staff/member snapshot stored on a scheduled match sheet.
public struct MatchSheetStaffEntry: Identifiable, Codable, Hashable, Sendable {
  public let entryId: UUID
  public var sourceOfficialId: UUID?
  public var displayName: String
  public var roleLabel: String?
  public var notes: String?
  public var sortOrder: Int
  public var category: MatchSheetStaffCategory

  public var id: UUID { self.entryId }

  public init(
    entryId: UUID = UUID(),
    sourceOfficialId: UUID? = nil,
    displayName: String,
    roleLabel: String? = nil,
    notes: String? = nil,
    sortOrder: Int,
    category: MatchSheetStaffCategory)
  {
    self.entryId = entryId
    self.sourceOfficialId = sourceOfficialId
    self.displayName = displayName
    self.roleLabel = roleLabel
    self.notes = notes
    self.sortOrder = sortOrder
    self.category = category
  }

  enum CodingKeys: String, CodingKey {
    case entryId
    case sourceOfficialId
    case displayName
    case roleLabel
    case notes
    case sortOrder
    case category
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.entryId = try container.decodeIfPresent(UUID.self, forKey: .entryId) ?? UUID()
    self.sourceOfficialId = try container.decodeIfPresent(UUID.self, forKey: .sourceOfficialId)
    self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    self.roleLabel = try container.decodeIfPresent(String.self, forKey: .roleLabel)
    self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    self.sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    self.category = try container.decodeIfPresent(MatchSheetStaffCategory.self, forKey: .category) ?? .staff
  }

  /// Returns whether the entry contains the denormalized display fields needed
  /// to stand alone after the source library roster changes.
  public var hasRequiredDisplayFields: Bool {
    self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
  }

  public func normalized(expectedCategory: MatchSheetStaffCategory? = nil) -> MatchSheetStaffEntry {
    MatchSheetStaffEntry(
      entryId: self.entryId,
      sourceOfficialId: self.sourceOfficialId,
      displayName: self.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      roleLabel: self.roleLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      notes: self.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      sortOrder: self.sortOrder,
      category: expectedCategory ?? self.category)
  }
}

/// Frozen schedule-owned participant snapshot for one side of a scheduled match.
public struct ScheduledMatchSheet: Codable, Hashable, Sendable {
  public var sourceTeamId: UUID?
  public var sourceTeamName: String?
  public var status: ScheduledMatchSheetStatus
  public var starters: [MatchSheetPlayerEntry]
  public var substitutes: [MatchSheetPlayerEntry]
  public var staff: [MatchSheetStaffEntry]
  public var otherMembers: [MatchSheetStaffEntry]
  public var updatedAt: Date

  public init(
    sourceTeamId: UUID? = nil,
    sourceTeamName: String? = nil,
    status: ScheduledMatchSheetStatus = .draft,
    starters: [MatchSheetPlayerEntry] = [],
    substitutes: [MatchSheetPlayerEntry] = [],
    staff: [MatchSheetStaffEntry] = [],
    otherMembers: [MatchSheetStaffEntry] = [],
    updatedAt: Date = Date())
  {
    self.sourceTeamId = sourceTeamId
    self.sourceTeamName = sourceTeamName
    self.status = status
    self.starters = starters
    self.substitutes = substitutes
    self.staff = staff
    self.otherMembers = otherMembers
    self.updatedAt = updatedAt
  }

  enum CodingKeys: String, CodingKey {
    case sourceTeamId
    case sourceTeamName
    case status
    case starters
    case substitutes
    case staff
    case otherMembers
    case updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.sourceTeamId = try container.decodeIfPresent(UUID.self, forKey: .sourceTeamId)
    self.sourceTeamName = try container.decodeIfPresent(String.self, forKey: .sourceTeamName)
    self.status = try container.decodeIfPresent(ScheduledMatchSheetStatus.self, forKey: .status) ?? .draft
    self.starters = try container.decodeIfPresent([MatchSheetPlayerEntry].self, forKey: .starters) ?? []
    self.substitutes = try container.decodeIfPresent([MatchSheetPlayerEntry].self, forKey: .substitutes) ?? []
    self.staff = try container.decodeIfPresent([MatchSheetStaffEntry].self, forKey: .staff) ?? []
    self.otherMembers = try container.decodeIfPresent([MatchSheetStaffEntry].self, forKey: .otherMembers) ?? []
    self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
  }

  public var hasAnyEntries: Bool {
    self.starters.isEmpty == false
      || self.substitutes.isEmpty == false
      || self.staff.isEmpty == false
      || self.otherMembers.isEmpty == false
  }

  public var meetsReadyRequirements: Bool {
    guard self.starters.isEmpty == false else { return false }
    return self.starters.allSatisfy(\.hasRequiredDisplayFields)
      && self.substitutes.allSatisfy(\.hasRequiredDisplayFields)
      && self.staff.allSatisfy(\.hasRequiredDisplayFields)
      && self.otherMembers.allSatisfy(\.hasRequiredDisplayFields)
  }

  public var isReady: Bool {
    self.status == .ready && self.meetsReadyRequirements
  }

  public var starterCount: Int { self.starters.count }
  public var substituteCount: Int { self.substitutes.count }
  public var staffCount: Int { self.staff.count }
  public var otherMemberCount: Int { self.otherMembers.count }

  /// Returns a normalized copy with stable ordering, trimmed display fields,
  /// and a status that is automatically demoted to `draft` if requirements are
  /// no longer satisfied.
  public func normalized() -> ScheduledMatchSheet {
    let normalizedStarters = Self.reindexedPlayers(
      self.starters.map { $0.normalized() }.sorted(by: MatchSheetPlayerEntry.sortComparator))
    let normalizedSubstitutes = Self.reindexedPlayers(
      self.substitutes.map { $0.normalized() }.sorted(by: MatchSheetPlayerEntry.sortComparator))
    let normalizedStaff = Self.reindexedStaff(
      self.staff.map { $0.normalized(expectedCategory: .staff) }.sorted(by: MatchSheetStaffEntry.sortComparator))
    let normalizedOtherMembers = Self.reindexedStaff(
      self.otherMembers
        .map { $0.normalized(expectedCategory: .otherMember) }
        .sorted(by: MatchSheetStaffEntry.sortComparator))

    var normalized = ScheduledMatchSheet(
      sourceTeamId: self.sourceTeamId,
      sourceTeamName: self.sourceTeamName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      status: self.status,
      starters: normalizedStarters,
      substitutes: normalizedSubstitutes,
      staff: normalizedStaff,
      otherMembers: normalizedOtherMembers,
      updatedAt: self.updatedAt)

    if normalized.meetsReadyRequirements == false {
      normalized.status = .draft
    }

    return normalized
  }

  private static func reindexedPlayers(_ entries: [MatchSheetPlayerEntry]) -> [MatchSheetPlayerEntry] {
    entries.enumerated().map { index, entry in
      var reindexed = entry
      reindexed.sortOrder = index
      return reindexed
    }
  }

  private static func reindexedStaff(_ entries: [MatchSheetStaffEntry]) -> [MatchSheetStaffEntry] {
    entries.enumerated().map { index, entry in
      var reindexed = entry
      reindexed.sortOrder = index
      return reindexed
    }
  }
}

/// Resolved on-field and bench state derived from a ready match sheet and
/// recorded substitution history.
public struct MatchSheetResolvedLineup: Equatable, Sendable {
  public var onField: [MatchSheetPlayerEntry]
  public var unusedSubstitutes: [MatchSheetPlayerEntry]

  public init(onField: [MatchSheetPlayerEntry], unusedSubstitutes: [MatchSheetPlayerEntry]) {
    self.onField = onField
    self.unusedSubstitutes = unusedSubstitutes
  }
}

/// Resolves the active on-field set and available substitutes from a frozen
/// match sheet plus saved substitution history.
public enum MatchSheetLineupResolver {
  public static func resolve(
    sheet: ScheduledMatchSheet,
    team: TeamSide,
    events: [MatchEventRecord]) -> MatchSheetResolvedLineup?
  {
    let normalized = sheet.normalized()
    guard normalized.isReady else { return nil }

    var onField = normalized.starters
    var unusedSubstitutes = normalized.substitutes

    let relevantEvents = events
      .filter { $0.team == team }
      .sorted { lhs, rhs in
        if lhs.actualTime != rhs.actualTime {
          return lhs.actualTime < rhs.actualTime
        }
        return lhs.timestamp < rhs.timestamp
      }

    for event in relevantEvents {
      switch event.eventType {
      case let .substitution(details):
        if let outgoingIndex = onField.firstIndex(where: { $0.matches(number: details.playerOut, name: details.playerOutName) }) {
          onField.remove(at: outgoingIndex)
        }

        if let incomingIndex = unusedSubstitutes.firstIndex(
          where: { $0.matches(number: details.playerIn, name: details.playerInName) })
        {
          let incoming = unusedSubstitutes.remove(at: incomingIndex)
          onField.append(incoming)
        }

      case let .card(details):
        guard details.dismissesPlayer else { continue }
        onField.removeAll { $0.matches(number: details.playerNumber, name: details.playerName) }
        unusedSubstitutes.removeAll { $0.matches(number: details.playerNumber, name: details.playerName) }

      default:
        continue
      }
    }

    onField.sort(by: MatchSheetPlayerEntry.sortComparator)
    unusedSubstitutes.sort(by: MatchSheetPlayerEntry.sortComparator)
    return MatchSheetResolvedLineup(onField: onField, unusedSubstitutes: unusedSubstitutes)
  }
}

private extension CardDetails {
  var dismissesPlayer: Bool {
    self.recipientType == .player && self.cardType == .red
  }
}

/// Watch-side roster resolution precedence for player-selection flows.
public enum MatchParticipantSelectionSource: Equatable, Sendable {
  case frozenSheet(lineup: MatchSheetResolvedLineup)
  case legacyLibrary(players: [MatchLibraryPlayer])
  case manualOnly
}

/// Resolves the official participant source for player-selection flows.
///
/// Precedence is:
/// 1. Ready frozen match sheets on both sides.
/// 2. Manual-only fallback if any explicit match-sheet model exists but is not watch-ready.
/// 3. Legacy library roster lookup only when the match has no sheet model at all.
public enum MatchParticipantSelectionResolver {
  public static func resolve(
    match: Match,
    team: TeamSide,
    libraryTeams: [MatchLibraryTeam],
    events: [MatchEventRecord]) -> MatchParticipantSelectionSource
  {
    if match.areMatchSheetsReadyForWatch {
      let sheet = team == .home ? match.homeMatchSheet : match.awayMatchSheet
      if let sheet, let lineup = MatchSheetLineupResolver.resolve(sheet: sheet, team: team, events: events) {
        return .frozenSheet(lineup: lineup)
      }
      return .manualOnly
    }

    if match.hasAnyMatchSheetData {
      return .manualOnly
    }

    if let legacyPlayers = self.resolveLegacyRoster(match: match, team: team, libraryTeams: libraryTeams) {
      return .legacyLibrary(players: legacyPlayers)
    }

    return .manualOnly
  }

  private static func resolveLegacyRoster(
    match: Match,
    team: TeamSide,
    libraryTeams: [MatchLibraryTeam]) -> [MatchLibraryPlayer]?
  {
    let expectedTeamId = team == .home ? match.homeTeamId : match.awayTeamId
    if let expectedTeamId,
       let teamRecord = libraryTeams.first(where: { $0.id == expectedTeamId }),
       teamRecord.players.isEmpty == false
    {
      return teamRecord.players
    }

    let expectedName = (team == .home ? match.homeTeam : match.awayTeam)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let matches = libraryTeams.filter { teamRecord in
      teamRecord.name.trimmingCharacters(in: .whitespacesAndNewlines)
        .localizedCaseInsensitiveCompare(expectedName) == .orderedSame
    }
    guard matches.count == 1, let teamRecord = matches.first, teamRecord.players.isEmpty == false else {
      return nil
    }
    return teamRecord.players
  }
}

private extension MatchSheetPlayerEntry {
  static let sortComparator: (MatchSheetPlayerEntry, MatchSheetPlayerEntry) -> Bool = { lhs, rhs in
    if lhs.sortOrder != rhs.sortOrder {
      return lhs.sortOrder < rhs.sortOrder
    }
    let lhsNumber = lhs.shirtNumber ?? Int.max
    let rhsNumber = rhs.shirtNumber ?? Int.max
    if lhsNumber != rhsNumber {
      return lhsNumber < rhsNumber
    }
    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
  }

  func matches(number: Int?, name: String?) -> Bool {
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    let selfName = self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

    if let number, let trimmedName {
      return self.shirtNumber == number && selfName == trimmedName
    }
    if let number {
      return self.shirtNumber == number
    }
    if let trimmedName {
      return selfName == trimmedName
    }
    return false
  }
}

private extension MatchSheetStaffEntry {
  static let sortComparator: (MatchSheetStaffEntry, MatchSheetStaffEntry) -> Bool = { lhs, rhs in
    if lhs.sortOrder != rhs.sortOrder {
      return lhs.sortOrder < rhs.sortOrder
    }
    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
  }
}

private extension String {
  var nilIfEmpty: String? {
    self.isEmpty ? nil : self
  }
}
