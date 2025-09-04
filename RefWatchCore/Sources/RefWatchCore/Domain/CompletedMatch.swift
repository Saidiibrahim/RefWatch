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
    public let match: Match
    public let events: [MatchEventRecord]

    // MARK: - Init
    public init(
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

