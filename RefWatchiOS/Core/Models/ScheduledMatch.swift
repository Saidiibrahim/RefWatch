//
//  ScheduledMatch.swift
//  RefWatchiOS
//
//  Lightweight model for upcoming/today matches shown in the Matches tab.
//

import Foundation
import RefWatchCore

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
    var homeTeamId: UUID?
    var awayTeamId: UUID?
    var homeMatchSheet: ScheduledMatchSheet?
    var awayMatchSheet: ScheduledMatchSheet?
    var kickoff: Date
    var competition: String?
    var notes: String?
    var status: Status = .scheduled

    /// Supabase metadata. Optional so JSON imports with older payloads continue to decode.
    var ownerSupabaseId: String?
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool = false
    var sourceDeviceId: String?
    var lastModifiedAt: Date?

    init(
        id: UUID = UUID(),
        homeTeam: String,
        awayTeam: String,
        homeTeamId: UUID? = nil,
        awayTeamId: UUID? = nil,
        homeMatchSheet: ScheduledMatchSheet? = nil,
        awayMatchSheet: ScheduledMatchSheet? = nil,
        kickoff: Date,
        competition: String? = nil,
        notes: String? = nil,
        status: Status = .scheduled,
        ownerSupabaseId: String? = nil,
        remoteUpdatedAt: Date? = nil,
        needsRemoteSync: Bool = false,
        sourceDeviceId: String? = nil,
        lastModifiedAt: Date? = nil
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.homeMatchSheet = homeMatchSheet
        self.awayMatchSheet = awayMatchSheet
        self.kickoff = kickoff
        self.competition = competition
        self.notes = notes
        self.status = status
        self.ownerSupabaseId = ownerSupabaseId
        self.remoteUpdatedAt = remoteUpdatedAt
        self.needsRemoteSync = needsRemoteSync
        self.sourceDeviceId = sourceDeviceId
        self.lastModifiedAt = lastModifiedAt
    }

    var hasAnyMatchSheetData: Bool {
        self.homeMatchSheet?.hasAnyEntries == true || self.awayMatchSheet?.hasAnyEntries == true
    }

    var areMatchSheetsReadyForWatch: Bool {
        self.homeMatchSheet?.isReady == true || self.awayMatchSheet?.isReady == true
    }
}

extension ScheduledMatch.Status {
    /// Decode status from database snake_case format.
    /// Database uses: scheduled, in_progress, completed, canceled.
    /// Swift enum uses: scheduled, inProgress, completed, canceled.
    init(fromDatabase raw: String) {
        switch raw {
        case "scheduled":
            self = .scheduled
        case "in_progress":
            self = .inProgress
        case "completed":
            self = .completed
        case "canceled":
            self = .canceled
        default:
            #if DEBUG
            print("⚠️ Unknown schedule status: '\(raw)', defaulting to .scheduled")
            #endif
            self = .scheduled
        }
    }

    /// Encode status to database snake_case format.
    /// Ensures consistency with Supabase schema expectations.
    var databaseValue: String {
        switch self {
        case .scheduled:
            return "scheduled"
        case .inProgress:
            return "in_progress"
        case .completed:
            return "completed"
        case .canceled:
            return "canceled"
        }
    }
}
