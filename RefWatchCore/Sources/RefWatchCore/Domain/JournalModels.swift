//
//  JournalModels.swift
//  RefWatchCore
//
//  Domain model for self-assessment journal entries linked to a completed match.
//

import Foundation

public struct JournalEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public let matchId: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var ownerId: String?

    // Simple structured fields for self-assessment
    public var rating: Int? // 1–5 optional
    public var overall: String?
    public var wentWell: String?
    public var toImprove: String?

    public init(
        id: UUID = UUID(),
        matchId: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        ownerId: String? = nil,
        rating: Int? = nil,
        overall: String? = nil,
        wentWell: String? = nil,
        toImprove: String? = nil
    ) {
        self.id = id
        self.matchId = matchId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ownerId = ownerId
        self.rating = rating
        self.overall = overall
        self.wentWell = wentWell
        self.toImprove = toImprove
    }
}

