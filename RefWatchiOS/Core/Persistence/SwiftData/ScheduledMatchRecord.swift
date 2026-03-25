//
//  ScheduledMatchRecord.swift
//  RefWatchiOS
//
//  SwiftData model for upcoming/today scheduled matches.
//  Stores team names redundantly to remain robust if linked teams are deleted.
//

import Foundation
import OSLog
import RefWatchCore
import SwiftData

@Model
final class ScheduledMatchRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kickoff: Date

    // Linked teams (optional)
    var homeTeam: TeamRecord?
    var awayTeam: TeamRecord?

    // Denormalized names for resilience and fast listing
    var homeName: String
    var awayName: String
    var homeTeamId: UUID?
    var awayTeamId: UUID?
    @Attribute(.externalStorage) var homeMatchSheetData: Data?
    @Attribute(.externalStorage) var awayMatchSheetData: Data?

    var competition: String?
    var notes: String?
    var statusRaw: String

    /// Supabase metadata
    var ownerSupabaseId: String?
    var lastModifiedAt: Date
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool
    var sourceDeviceId: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kickoff: Date,
        homeTeam: TeamRecord? = nil,
        awayTeam: TeamRecord? = nil,
        homeName: String,
        awayName: String,
        homeTeamId: UUID? = nil,
        awayTeamId: UUID? = nil,
        homeMatchSheet: ScheduledMatchSheet? = nil,
        awayMatchSheet: ScheduledMatchSheet? = nil,
        competition: String? = nil,
        notes: String? = nil,
        status: ScheduledMatch.Status = .scheduled,
        ownerSupabaseId: String? = nil,
        lastModifiedAt: Date = Date(),
        remoteUpdatedAt: Date? = nil,
        needsRemoteSync: Bool = true,
        sourceDeviceId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kickoff = kickoff
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeName = homeName
        self.awayName = awayName
        self.homeTeamId = homeTeamId ?? homeTeam?.id
        self.awayTeamId = awayTeamId ?? awayTeam?.id
        self.homeMatchSheetData = Self.encodeMatchSheet(homeMatchSheet)
        self.awayMatchSheetData = Self.encodeMatchSheet(awayMatchSheet)
        self.competition = competition
        self.notes = notes
        self.statusRaw = status.databaseValue
        self.ownerSupabaseId = ownerSupabaseId
        self.lastModifiedAt = lastModifiedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
        self.sourceDeviceId = sourceDeviceId
    }
}

extension ScheduledMatchRecord {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.refwatch.app",
        category: "SchedulePersistence")

    var homeMatchSheet: ScheduledMatchSheet? {
        get { Self.decodeMatchSheet(homeMatchSheetData) }
        set { homeMatchSheetData = Self.encodeMatchSheet(newValue) }
    }

    var awayMatchSheet: ScheduledMatchSheet? {
        get { Self.decodeMatchSheet(awayMatchSheetData) }
        set { awayMatchSheetData = Self.encodeMatchSheet(newValue) }
    }

    var status: ScheduledMatch.Status {
        get { ScheduledMatch.Status(fromDatabase: statusRaw) }
        set { statusRaw = newValue.databaseValue }
    }

    func update(from item: ScheduledMatch, markModified: Bool = true, dateProvider: () -> Date = Date.init) {
        homeName = item.homeTeam
        awayName = item.awayTeam
        homeTeamId = item.homeTeamId ?? homeTeam?.id
        awayTeamId = item.awayTeamId ?? awayTeam?.id
        homeMatchSheet = item.homeMatchSheet?.normalized()
        awayMatchSheet = item.awayMatchSheet?.normalized()
        kickoff = item.kickoff
        competition = item.competition
        notes = item.notes
        status = item.status
        sourceDeviceId = item.sourceDeviceId
        if markModified {
            markLocallyModified(at: dateProvider(), ownerSupabaseId: item.ownerSupabaseId)
        }
    }

    func markLocallyModified(at date: Date = Date(), ownerSupabaseId ownerId: String? = nil) {
        lastModifiedAt = date
        needsRemoteSync = true
        if let ownerId {
            ownerSupabaseId = ownerId
        }
    }

    func applyRemoteSyncMetadata(
        ownerId: String?,
        remoteUpdatedAt updatedAt: Date?,
        status: ScheduledMatch.Status,
        synchronizedAt: Date = Date()
    ) {
        ownerSupabaseId = ownerId ?? ownerSupabaseId
        remoteUpdatedAt = updatedAt
        needsRemoteSync = false
        lastModifiedAt = synchronizedAt
        statusRaw = status.databaseValue
    }

    private static let matchSheetEncoder = JSONEncoder()
    private static let matchSheetDecoder = JSONDecoder()

    private static func encodeMatchSheet(_ sheet: ScheduledMatchSheet?) -> Data? {
        guard let normalized = sheet?.normalized() else { return nil }
        return try? matchSheetEncoder.encode(normalized)
    }

    private static func decodeMatchSheet(_ data: Data?) -> ScheduledMatchSheet? {
        guard let data else { return nil }
        do {
            return try matchSheetDecoder.decode(ScheduledMatchSheet.self, from: data)
        } catch {
            log.error("Failed to decode scheduled match sheet data: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
