//
//  CompletedMatch.swift
//  RefWatchCore
//
//  Snapshot of a finished match including final scores,
//  configuration, and the full event log for persistence/history.
//

import Foundation

public struct CompletedMatch: Identifiable, Codable {
    // MARK: - Identity & Versioning
    public let id: UUID
    public let schemaVersion: Int

    // MARK: - Content
    public let completedAt: Date
    public var match: Match
    public let events: [MatchEventRecord]
    // Optional owner identifier for multi-user tagging (iOS may set via auth)
    public var ownerId: String?

    // MARK: - Foreign Key Bridges
    public var scheduledMatchId: UUID? {
        get { match.scheduledMatchId }
        set { match.scheduledMatchId = newValue }
    }

    public var homeTeamId: UUID? {
        get { match.homeTeamId }
        set { match.homeTeamId = newValue }
    }

    public var awayTeamId: UUID? {
        get { match.awayTeamId }
        set { match.awayTeamId = newValue }
    }

    public var competitionId: UUID? {
        get { match.competitionId }
        set { match.competitionId = newValue }
    }

    public var competitionName: String? {
        get { match.competitionName }
        set { match.competitionName = newValue }
    }

    public var venueId: UUID? {
        get { match.venueId }
        set { match.venueId = newValue }
    }

    public var venueName: String? {
        get { match.venueName }
        set { match.venueName = newValue }
    }

    // MARK: - Init
    public init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        match: Match,
        events: [MatchEventRecord],
        schemaVersion: Int = 1,
        ownerId: String? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.match = match
        self.events = events
        self.schemaVersion = schemaVersion
        self.ownerId = ownerId
    }

    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case completedAt
        case match
        case events
        case ownerId
        case scheduledMatchId
        case homeTeamId
        case awayTeamId
        case competitionId
        case competitionName
        case venueId
        case venueName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        match = try container.decode(Match.self, forKey: .match)
        events = try container.decode([MatchEventRecord].self, forKey: .events)
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId)

        if let value = try container.decodeIfPresent(UUID.self, forKey: .scheduledMatchId) {
            match.scheduledMatchId = value
        }
        if let value = try container.decodeIfPresent(UUID.self, forKey: .homeTeamId) {
            match.homeTeamId = value
        }
        if let value = try container.decodeIfPresent(UUID.self, forKey: .awayTeamId) {
            match.awayTeamId = value
        }
        if let value = try container.decodeIfPresent(UUID.self, forKey: .competitionId) {
            match.competitionId = value
        }
        if let value = try container.decodeIfPresent(String.self, forKey: .competitionName) {
            match.competitionName = value
        }
        if let value = try container.decodeIfPresent(UUID.self, forKey: .venueId) {
            match.venueId = value
        }
        if let value = try container.decodeIfPresent(String.self, forKey: .venueName) {
            match.venueName = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(match, forKey: .match)
        try container.encode(events, forKey: .events)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
        try container.encodeIfPresent(match.scheduledMatchId, forKey: .scheduledMatchId)
        try container.encodeIfPresent(match.homeTeamId, forKey: .homeTeamId)
        try container.encodeIfPresent(match.awayTeamId, forKey: .awayTeamId)
        try container.encodeIfPresent(match.competitionId, forKey: .competitionId)
        try container.encodeIfPresent(match.competitionName, forKey: .competitionName)
        try container.encodeIfPresent(match.venueId, forKey: .venueId)
        try container.encodeIfPresent(match.venueName, forKey: .venueName)
    }
}
