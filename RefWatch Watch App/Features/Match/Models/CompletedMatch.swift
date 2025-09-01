//
//  CompletedMatch.swift
//  RefWatch Watch App
//
//  Description: Snapshot of a finished match including final scores,
//  configuration, and the full event log for persistence/history.
//

import Foundation

struct CompletedMatch: Identifiable, Codable {
    // MARK: - Identity & Versioning
    let id: UUID
    let schemaVersion: Int

    // MARK: - Content
    let completedAt: Date
    let match: Match
    let events: [MatchEventRecord]

    // MARK: - Init
    init(
        id: UUID = UUID(),
        completedAt: Date = Date(),
        match: Match,
        events: [MatchEventRecord],
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.completedAt = completedAt
        self.match = match
        self.events = events
        self.schemaVersion = schemaVersion
    }
}

