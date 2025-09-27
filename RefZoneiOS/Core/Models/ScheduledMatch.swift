//
//  ScheduledMatch.swift
//  RefZoneiOS
//
//  Lightweight model for upcoming/today matches shown in the Matches tab.
//

import Foundation

struct ScheduledMatch: Identifiable, Codable, Hashable {
    enum Status: String, Codable, CaseIterable {
        case scheduled
        case inProgress
        case completed
        case canceled
    }

    let id: UUID
    var homeTeam: String
    var awayTeam: String
    var kickoff: Date
    var competition: String?
    var notes: String?
    var status: Status = .scheduled

    /// Supabase metadata. Optional so JSON imports with older payloads continue to decode.
    var ownerSupabaseId: String?
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool = false
    var sourceDeviceId: String?

    init(
        id: UUID = UUID(),
        homeTeam: String,
        awayTeam: String,
        kickoff: Date,
        competition: String? = nil,
        notes: String? = nil,
        status: Status = .scheduled,
        ownerSupabaseId: String? = nil,
        remoteUpdatedAt: Date? = nil,
        needsRemoteSync: Bool = false,
        sourceDeviceId: String? = nil
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.kickoff = kickoff
        self.competition = competition
        self.notes = notes
        self.status = status
        self.ownerSupabaseId = ownerSupabaseId
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
        self.sourceDeviceId = sourceDeviceId
    }
}
