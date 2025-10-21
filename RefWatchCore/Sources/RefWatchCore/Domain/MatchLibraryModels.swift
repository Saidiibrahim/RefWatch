//
//  MatchLibraryModels.swift
//  RefWatchCore
//
//  Lightweight value types that expose synced library data
//  (teams, competitions, venues, schedules) to shared UI.
//

import Foundation

public struct MatchLibraryPlayer: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let number: Int?
    public let position: String?
    public let notes: String?

    public init(id: UUID, name: String, number: Int? = nil, position: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.notes = notes
    }
}

public struct MatchLibraryOfficial: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let role: String
    public let phone: String?
    public let email: String?

    public init(id: UUID, name: String, role: String, phone: String? = nil, email: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.phone = phone
        self.email = email
    }
}

public struct MatchLibraryTeam: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let shortName: String?
    public let division: String?
    public let primaryColorHex: String?
    public let secondaryColorHex: String?
    public let players: [MatchLibraryPlayer]
    public let officials: [MatchLibraryOfficial]

    public init(
        id: UUID,
        name: String,
        shortName: String? = nil,
        division: String? = nil,
        primaryColorHex: String? = nil,
        secondaryColorHex: String? = nil,
        players: [MatchLibraryPlayer] = [],
        officials: [MatchLibraryOfficial] = []
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.division = division
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.players = players
        self.officials = officials
    }
}

public struct MatchLibraryCompetition: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let level: String?

    public init(id: UUID, name: String, level: String? = nil) {
        self.id = id
        self.name = name
        self.level = level
    }
}

public struct MatchLibraryVenue: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let city: String?
    public let country: String?
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: UUID,
        name: String,
        city: String? = nil,
        country: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct MatchLibrarySchedule: Identifiable, Equatable {
    public let id: UUID
    public let homeName: String
    public let awayName: String
    public let kickoff: Date
    public let competitionName: String?
    public let notes: String?
    public let statusRaw: String
    public let sourceDeviceId: String?
    public let venueName: String?

    public init(
        id: UUID,
        homeName: String,
        awayName: String,
        kickoff: Date,
        competitionName: String? = nil,
        notes: String? = nil,
        statusRaw: String,
        sourceDeviceId: String? = nil,
        venueName: String? = nil
    ) {
        self.id = id
        self.homeName = homeName
        self.awayName = awayName
        self.kickoff = kickoff
        self.competitionName = competitionName
        self.notes = notes
        self.statusRaw = statusRaw
        self.sourceDeviceId = sourceDeviceId
        self.venueName = venueName
    }
}

public struct MatchLibrarySnapshot: Equatable {
    public var teams: [MatchLibraryTeam]
    public var competitions: [MatchLibraryCompetition]
    public var venues: [MatchLibraryVenue]
    public var schedules: [MatchLibrarySchedule]

    public init(
        teams: [MatchLibraryTeam] = [],
        competitions: [MatchLibraryCompetition] = [],
        venues: [MatchLibraryVenue] = [],
        schedules: [MatchLibrarySchedule] = []
    ) {
        self.teams = teams
        self.competitions = competitions
        self.venues = venues
        self.schedules = schedules
    }
}
