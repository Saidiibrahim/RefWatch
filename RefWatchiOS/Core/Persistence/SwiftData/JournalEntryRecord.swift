//
//  JournalEntryRecord.swift
//  RefWatchiOS
//
//  SwiftData model for storing self-assessment journal entries.
//

import Foundation
import SwiftData

@Model
final class JournalEntryRecord {
    @Attribute(.unique) var id: UUID
    var matchId: UUID
    var createdAt: Date
    var updatedAt: Date
    var ownerId: String?

    var rating: Int?
    var overall: String?
    var wentWell: String?
    var toImprove: String?

    init(
        id: UUID,
        matchId: UUID,
        createdAt: Date,
        updatedAt: Date,
        ownerId: String?,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
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
