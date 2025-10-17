import XCTest
@testable import RefWatchCore

@MainActor
final class MatchViewModel_LibraryIntegrationTests: XCTestCase {
    func testUpdateLibraryPopulatesSavedMatchesAndDefaults() {
        let viewModel = MatchViewModel(history: InMemoryHistory())

        let teamA = MatchLibraryTeam(id: UUID(), name: "Team A")
        let teamB = MatchLibraryTeam(id: UUID(), name: "Team B")
        let schedule = MatchLibrarySchedule(
            id: UUID(),
            homeName: "Team A",
            awayName: "Team C",
            kickoff: Date().addingTimeInterval(3600),
            competitionName: "Premier Cup",
            statusRaw: "upcoming"
        )
        let snapshot = MatchLibrarySnapshot(teams: [teamA, teamB], competitions: [], venues: [], schedules: [schedule])

        viewModel.updateLibrary(with: snapshot)

        XCTAssertEqual(viewModel.libraryTeams.count, 2)
        XCTAssertEqual(viewModel.savedMatches.count, 1)
        XCTAssertEqual(viewModel.savedMatches.first?.homeTeam, "Team A")
        XCTAssertEqual(viewModel.newMatch.homeTeam, "Team A")
        XCTAssertEqual(viewModel.newMatch.awayTeam, "Team B")

        viewModel.newMatch.homeTeam = "Watch Select"
        viewModel.newMatch.awayTeam = "Opp X"
        viewModel.createMatch()

        XCTAssertEqual(viewModel.savedMatches.count, 2)
        XCTAssertTrue(viewModel.savedMatches.contains { $0.homeTeam == "Watch Select" })

        viewModel.updateLibrary(with: snapshot)

        XCTAssertEqual(viewModel.savedMatches.count, 2)
        XCTAssertTrue(viewModel.savedMatches.contains { $0.homeTeam == "Watch Select" })
    }
}

@MainActor
private final class InMemoryHistory: MatchHistoryStoring {
    private var records: [CompletedMatch] = []

    func loadAll() throws -> [CompletedMatch] { records }
    func save(_ match: CompletedMatch) throws { records.append(match) }
    func delete(id: UUID) throws { records.removeAll { $0.id == id } }
    func wipeAll() throws { records.removeAll() }
}
