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
        secondaryColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.division = division
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.players = []
        self.officials = []
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

