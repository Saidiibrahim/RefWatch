//
//  AggregateSyncPayloads.swift
//  RefWatchCore
//
//  Shared payload schemas for watch ↔︎ iPhone aggregate synchronisation.
//

import Foundation

public enum AggregateSyncSchema {
    public static let currentVersion = 1
}

public enum AggregateSyncEntity: String, Codable, CaseIterable {
    case team
    case competition
    case venue
    case schedule
}

public enum AggregateDeltaAction: String, Codable, CaseIterable {
    case create
    case update
    case delete
}

public enum AggregateSyncOrigin: String, Codable {
    case watch
    case iphone
}

public struct AggregateSnapshotPayload: Codable, Equatable {
    public struct HistorySummary: Codable, Equatable {
        public var id: UUID
        public var completedAt: Date
        public var homeName: String
        public var awayName: String
        public var homeScore: Int
        public var awayScore: Int
        public var competitionName: String?
        public var venueName: String?

        public init(
            id: UUID,
            completedAt: Date,
            homeName: String,
            awayName: String,
            homeScore: Int,
            awayScore: Int,
            competitionName: String? = nil,
            venueName: String? = nil
        ) {
            self.id = id
            self.completedAt = completedAt
            self.homeName = homeName
            self.awayName = awayName
            self.homeScore = homeScore
            self.awayScore = awayScore
            self.competitionName = competitionName
            self.venueName = venueName
        }
    }
    public struct Settings: Codable, Equatable {
        public enum ConnectivityStatus: String, Codable {
            case reachable
            case unreachable
            case unknown
        }

        public var connectivityStatus: ConnectivityStatus
        public var lastSuccessfulSupabaseSync: Date?
        public var requiresBackfill: Bool

        public init(connectivityStatus: ConnectivityStatus, lastSuccessfulSupabaseSync: Date? = nil, requiresBackfill: Bool = false) {
            self.connectivityStatus = connectivityStatus
            self.lastSuccessfulSupabaseSync = lastSuccessfulSupabaseSync
            self.requiresBackfill = requiresBackfill
        }
    }

    public struct ChunkMetadata: Codable, Equatable {
        public var index: Int
        public var count: Int

        public init(index: Int, count: Int) {
            self.index = index
            self.count = count
        }
    }

    public struct Team: Codable, Equatable {
        public struct Player: Codable, Equatable {
            public var id: UUID
            public var name: String
            public var number: Int?
            public var position: String?
            public var notes: String?

            public init(id: UUID, name: String, number: Int? = nil, position: String? = nil, notes: String? = nil) {
                self.id = id
                self.name = name
                self.number = number
                self.position = position
                self.notes = notes
            }
        }

        public struct Official: Codable, Equatable {
            public var id: UUID
            public var name: String
            public var roleRaw: String
            public var phone: String?
            public var email: String?

            public init(id: UUID, name: String, roleRaw: String, phone: String? = nil, email: String? = nil) {
                self.id = id
                self.name = name
                self.roleRaw = roleRaw
                self.phone = phone
                self.email = email
            }
        }

        public var id: UUID
        public var ownerSupabaseId: String?
        public var lastModifiedAt: Date
        public var remoteUpdatedAt: Date?
        public var name: String
        public var shortName: String?
        public var division: String?
        public var primaryColorHex: String?
        public var secondaryColorHex: String?
        public var players: [Player]
        public var officials: [Official]

        public init(
            id: UUID,
            ownerSupabaseId: String?,
            lastModifiedAt: Date,
            remoteUpdatedAt: Date?,
            name: String,
            shortName: String?,
            division: String?,
            primaryColorHex: String?,
            secondaryColorHex: String?,
            players: [Player],
            officials: [Official]
        ) {
            self.id = id
            self.ownerSupabaseId = ownerSupabaseId
            self.lastModifiedAt = lastModifiedAt
            self.remoteUpdatedAt = remoteUpdatedAt
            self.name = name
            self.shortName = shortName
            self.division = division
            self.primaryColorHex = primaryColorHex
            self.secondaryColorHex = secondaryColorHex
            self.players = players
            self.officials = officials
        }
    }

    public struct Competition: Codable, Equatable {
        public var id: UUID
        public var ownerSupabaseId: String?
        public var lastModifiedAt: Date
        public var remoteUpdatedAt: Date?
        public var name: String
        public var level: String?

        public init(id: UUID, ownerSupabaseId: String?, lastModifiedAt: Date, remoteUpdatedAt: Date?, name: String, level: String?) {
            self.id = id
            self.ownerSupabaseId = ownerSupabaseId
            self.lastModifiedAt = lastModifiedAt
            self.remoteUpdatedAt = remoteUpdatedAt
            self.name = name
            self.level = level
        }
    }

    public struct Venue: Codable, Equatable {
        public var id: UUID
        public var ownerSupabaseId: String?
        public var lastModifiedAt: Date
        public var remoteUpdatedAt: Date?
        public var name: String
        public var city: String?
        public var country: String?
        public var latitude: Double?
        public var longitude: Double?

        public init(
            id: UUID,
            ownerSupabaseId: String?,
            lastModifiedAt: Date,
            remoteUpdatedAt: Date?,
            name: String,
            city: String?,
            country: String?,
            latitude: Double?,
            longitude: Double?
        ) {
            self.id = id
            self.ownerSupabaseId = ownerSupabaseId
            self.lastModifiedAt = lastModifiedAt
            self.remoteUpdatedAt = remoteUpdatedAt
            self.name = name
            self.city = city
            self.country = country
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public struct Schedule: Codable, Equatable {
        public var id: UUID
        public var ownerSupabaseId: String?
        public var lastModifiedAt: Date
        public var remoteUpdatedAt: Date?
        public var homeName: String
        public var awayName: String
        public var kickoff: Date
        public var competition: String?
        public var notes: String?
        public var statusRaw: String
        public var sourceDeviceId: String?

        public init(
            id: UUID,
            ownerSupabaseId: String?,
            lastModifiedAt: Date,
            remoteUpdatedAt: Date?,
            homeName: String,
            awayName: String,
            kickoff: Date,
            competition: String?,
            notes: String?,
            statusRaw: String,
            sourceDeviceId: String?
        ) {
            self.id = id
            self.ownerSupabaseId = ownerSupabaseId
            self.lastModifiedAt = lastModifiedAt
            self.remoteUpdatedAt = remoteUpdatedAt
            self.homeName = homeName
            self.awayName = awayName
            self.kickoff = kickoff
            self.competition = competition
            self.notes = notes
            self.statusRaw = statusRaw
            self.sourceDeviceId = sourceDeviceId
        }
    }

    public var schemaVersion: Int
    public var generatedAt: Date
    public var lastSyncedAt: Date?
    public var acknowledgedChangeIds: [UUID]
    public var chunk: ChunkMetadata?
    public var settings: Settings?
    public var teams: [Team]
    public var venues: [Venue]
    public var competitions: [Competition]
    public var schedules: [Schedule]
    public var history: [HistorySummary]

    public init(
        schemaVersion: Int = AggregateSyncSchema.currentVersion,
        generatedAt: Date,
        lastSyncedAt: Date?,
        acknowledgedChangeIds: [UUID],
        chunk: ChunkMetadata?,
        settings: Settings?,
        teams: [Team],
        venues: [Venue],
        competitions: [Competition],
        schedules: [Schedule],
        history: [HistorySummary] = []
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.lastSyncedAt = lastSyncedAt
        self.acknowledgedChangeIds = acknowledgedChangeIds
        self.chunk = chunk
        self.settings = settings
        self.teams = teams
        self.venues = venues
        self.competitions = competitions
        self.schedules = schedules
        self.history = history
    }

    // MARK: - Custom Codable for Backward Compatibility

    enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, lastSyncedAt, acknowledgedChangeIds
        case chunk, settings, teams, venues, competitions, schedules, history
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        acknowledgedChangeIds = try container.decode([UUID].self, forKey: .acknowledgedChangeIds)
        chunk = try container.decodeIfPresent(ChunkMetadata.self, forKey: .chunk)
        settings = try container.decodeIfPresent(Settings.self, forKey: .settings)
        teams = try container.decode([Team].self, forKey: .teams)
        venues = try container.decode([Venue].self, forKey: .venues)
        competitions = try container.decode([Competition].self, forKey: .competitions)
        schedules = try container.decode([Schedule].self, forKey: .schedules)
        // Default to empty array if key missing (backward compatibility with pre-history builds)
        history = try container.decodeIfPresent([HistorySummary].self, forKey: .history) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
        try container.encode(acknowledgedChangeIds, forKey: .acknowledgedChangeIds)
        try container.encodeIfPresent(chunk, forKey: .chunk)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encode(teams, forKey: .teams)
        try container.encode(venues, forKey: .venues)
        try container.encode(competitions, forKey: .competitions)
        try container.encode(schedules, forKey: .schedules)
        try container.encode(history, forKey: .history)
    }
}

public struct AggregateDeltaEnvelope: Codable, Equatable {
    public var type: String
    public var schemaVersion: Int
    public var id: UUID
    public var entity: AggregateSyncEntity
    public var action: AggregateDeltaAction
    public var payload: Data?
    public var modifiedAt: Date
    public var origin: AggregateSyncOrigin
    public var dependencies: [UUID]
    public var idempotencyKey: UUID
    public var requiresSnapshotRefresh: Bool

    public init(
        schemaVersion: Int = AggregateSyncSchema.currentVersion,
        id: UUID,
        entity: AggregateSyncEntity,
        action: AggregateDeltaAction,
        payload: Data?,
        modifiedAt: Date,
        origin: AggregateSyncOrigin,
        dependencies: [UUID] = [],
        idempotencyKey: UUID? = nil,
        requiresSnapshotRefresh: Bool = false
    ) {
        self.type = "aggregateDelta"
        self.schemaVersion = schemaVersion
        self.id = id
        self.entity = entity
        self.action = action
        self.payload = payload
        self.modifiedAt = modifiedAt
        self.origin = origin
        self.dependencies = dependencies
        self.idempotencyKey = idempotencyKey ?? id
        self.requiresSnapshotRefresh = requiresSnapshotRefresh
    }

    public func decodePayload<T: Decodable>(
        as type: T.Type,
        using decoder: JSONDecoder = AggregateSyncCoding.makeDecoder()
    ) throws -> T {
        guard let payload else {
            throw AggregateSyncPayloadError.missingPayload
        }
        return try decoder.decode(T.self, from: payload)
    }
}

public struct ManualSyncRequestMessage: Codable, Equatable {
    public enum Reason: String, Codable {
        case manual
        case connectivity
    }

    public var type: String
    public var schemaVersion: Int
    public var reason: Reason

    public init(schemaVersion: Int = AggregateSyncSchema.currentVersion, reason: Reason) {
        self.type = "syncRequest"
        self.schemaVersion = schemaVersion
        self.reason = reason
    }
}

public struct ManualSyncStatusMessage: Codable, Equatable {
    public var type: String
    public var schemaVersion: Int
    public var reachable: Bool
    public var queued: Int
    public var queuedDeltas: Int
    public var pendingSnapshotChunks: Int
    public var lastSnapshot: Date?

    public init(
        schemaVersion: Int = AggregateSyncSchema.currentVersion,
        reachable: Bool,
        queued: Int,
        queuedDeltas: Int,
        pendingSnapshotChunks: Int,
        lastSnapshot: Date?
    ) {
        self.type = "syncStatus"
        self.schemaVersion = schemaVersion
        self.reachable = reachable
        self.queued = queued
        self.queuedDeltas = queuedDeltas
        self.pendingSnapshotChunks = pendingSnapshotChunks
        self.lastSnapshot = lastSnapshot
    }
}

public enum AggregateSyncPayloadError: Error {
    case missingPayload
    case decodeFailure
}

public enum AggregateSyncCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date))
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = iso8601Formatter.date(from: string) ?? fallbackFormatter.date(from: string) else {
                throw AggregateSyncPayloadError.decodeFailure
            }
            return date
        }
        return decoder
    }
}

private extension AggregateSyncCoding {
    static func iso8601String(from date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    static var iso8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static var fallbackFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
