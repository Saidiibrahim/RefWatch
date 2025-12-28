import Foundation
import RefWatchCore

@MainActor
extension WatchAggregateLibraryStore {
  func makeMatchLibrarySnapshot() throws -> MatchLibrarySnapshot {
    let teamRecords = try fetchTeams()
    let competitionRecords = try fetchCompetitions()
    let venueRecords = try fetchVenues()
    let scheduleRecords = try fetchSchedules()

    let teams = teamRecords.map { record -> MatchLibraryTeam in
      let orderedPlayers = record.players.sorted { lhs, rhs in
        if let ln = lhs.number, let rn = rhs.number, ln != rn {
          return ln < rn
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      let players = orderedPlayers.map { player in
        MatchLibraryPlayer(
          id: player.id,
          name: player.name,
          number: player.number,
          position: player.position,
          notes: player.notes
        )
      }

      let officials = record.officials
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        .map { official in
          MatchLibraryOfficial(
            id: official.id,
            name: official.name,
            role: official.roleRaw,
            phone: official.phone,
            email: official.email
          )
        }

      return MatchLibraryTeam(
        id: record.id,
        name: record.name,
        shortName: record.shortName,
        division: record.division,
        primaryColorHex: record.primaryColorHex,
        secondaryColorHex: record.secondaryColorHex,
        players: players,
        officials: officials
      )
    }

    let competitions = competitionRecords.map { record in
      MatchLibraryCompetition(id: record.id, name: record.name, level: record.level)
    }

    let venues = venueRecords.map { record in
      MatchLibraryVenue(
        id: record.id,
        name: record.name,
        city: record.city,
        country: record.country,
        latitude: record.latitude,
        longitude: record.longitude
      )
    }

    let schedules = scheduleRecords.map { record in
      MatchLibrarySchedule(
        id: record.id,
        homeName: record.homeName,
        awayName: record.awayName,
        kickoff: record.kickoff,
        competitionName: record.competition,
        notes: record.notes,
        statusRaw: record.statusRaw,
        sourceDeviceId: record.sourceDeviceId
      )
    }

    return MatchLibrarySnapshot(
      teams: teams,
      competitions: competitions,
      venues: venues,
      schedules: schedules
    )
  }
}
