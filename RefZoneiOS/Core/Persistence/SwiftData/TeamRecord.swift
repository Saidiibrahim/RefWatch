//
//  TeamRecord.swift
//  RefZoneiOS
//
//  SwiftData models for Teams library (Phase 1)
//

import Foundation
import SwiftData

@Model
final class TeamRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var shortName: String?
    var division: String?
    var primaryColorHex: String?
    var secondaryColorHex: String?

    /// Supabase user id that owns this record once identity sync succeeds.
    var ownerSupabaseId: String?

    /// Timestamp captured the last time a local mutation occurred (for sync ordering).
    var lastModifiedAt: Date

    /// Timestamp reported by Supabase (`teams.updated_at`) the last time we pulled remote data.
    var remoteUpdatedAt: Date?

    /// Indicates the record (or one of its children) needs to be pushed to Supabase.
    var needsRemoteSync: Bool

    @Relationship(deleteRule: .cascade, inverse: \PlayerRecord.team)
    var players: [PlayerRecord]

    @Relationship(deleteRule: .cascade, inverse: \TeamOfficialRecord.team)
    var officials: [TeamOfficialRecord]

    init(
        id: UUID = UUID(),
        name: String,
        shortName: String? = nil,
        division: String? = nil,
        primaryColorHex: String? = nil,
        secondaryColorHex: String? = nil,
        ownerSupabaseId: String? = nil,
        lastModifiedAt: Date = Date(),
        remoteUpdatedAt: Date? = nil,
        needsRemoteSync: Bool = true
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.division = division
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.ownerSupabaseId = ownerSupabaseId
        self.lastModifiedAt = lastModifiedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
        self.players = []
        self.officials = []
    }
}

extension TeamRecord {
    /// Marks the record as locally dirty so the sync layer can enqueue a push.
    func markLocallyModified(at date: Date = Date(), ownerSupabaseId ownerId: String? = nil) {
        lastModifiedAt = date
        needsRemoteSync = true
        if let ownerId {
            ownerSupabaseId = ownerId
        }
    }

    /// Applies remote metadata after a successful pull/upsert so future syncs can diff correctly.
    func applyRemoteSyncMetadata(ownerId: String?, remoteUpdatedAt updatedAt: Date?, synchronizedAt syncDate: Date = Date()) {
        ownerSupabaseId = ownerId ?? ownerSupabaseId
        remoteUpdatedAt = updatedAt
        needsRemoteSync = false
        lastModifiedAt = syncDate
    }
}

@Model
final class PlayerRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var number: Int?
    var position: String?
    var notes: String?

    var team: TeamRecord?

    init(
        id: UUID = UUID(),
        name: String,
        number: Int? = nil,
        position: String? = nil,
        notes: String? = nil,
        team: TeamRecord? = nil
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.notes = notes
        self.team = team
    }
}

@Model
final class TeamOfficialRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var roleRaw: String
    var phone: String?
    var email: String?

    var team: TeamRecord?

    init(
        id: UUID = UUID(),
        name: String,
        roleRaw: String,
        phone: String? = nil,
        email: String? = nil,
        team: TeamRecord? = nil
    ) {
        self.id = id
        self.name = name
        self.roleRaw = roleRaw
        self.phone = phone
        self.email = email
        self.team = team
    }
}
