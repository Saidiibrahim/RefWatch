import Testing
@testable import RefWatch_Watch_App
@testable import RefWatchCore

@MainActor
@Suite("MatchViewModel Saved Match Filtering")
struct MatchViewModelSavedMatchFilteringTests {

    @Test("Excludes completed schedules from saved matches")
    func excludesCompletedSchedules() async {
        let viewModel = MatchViewModel(history: InMemoryHistory())

        let upcomingSchedule = MatchLibrarySchedule(
            id: UUID(),
            homeName: "Team A",
            awayName: "Team B",
            kickoff: Date().addingTimeInterval(3600),
            statusRaw: "scheduled"
        )

        let completedSchedule = MatchLibrarySchedule(
            id: UUID(),
            homeName: "Team C",
            awayName: "Team D",
            kickoff: Date().addingTimeInterval(-3600),
            statusRaw: "completed"
        )

        let snapshot = MatchLibrarySnapshot(schedules: [upcomingSchedule, completedSchedule])
        viewModel.updateLibrary(with: snapshot)

        #expect(viewModel.savedMatches.count == 1)
        #expect(viewModel.savedMatches.first?.homeTeam == "Team A")
    }

    @Test("Retains in-progress schedules")
    func retainsInProgressSchedules() async {
        let viewModel = MatchViewModel(history: InMemoryHistory())

        let inProgressSchedule = MatchLibrarySchedule(
            id: UUID(),
            homeName: "Live A",
            awayName: "Live B",
            kickoff: Date(),
            statusRaw: "in_progress"
        )

        let snapshot = MatchLibrarySnapshot(schedules: [inProgressSchedule])
        viewModel.updateLibrary(with: snapshot)

        #expect(viewModel.savedMatches.count == 1)
        #expect(viewModel.savedMatches.first?.homeTeam == "Live A")
    }

    @Test("Prunes local match on finalize")
    func prunesLocalMatchOnFinalize() async {
        let viewModel = MatchViewModel(history: InMemoryHistory())

        viewModel.newMatch.homeTeam = "Local A"
        viewModel.newMatch.awayTeam = "Local B"
        viewModel.createMatch()

        let initialCount = viewModel.savedMatches.count
        #expect(initialCount == 1)

        viewModel.startMatch()
        viewModel.finalizeMatch()

        #expect(viewModel.savedMatches.isEmpty)
    }
}

@MainActor
private final class InMemoryHistory: MatchHistoryStoring {
    private var matches: [CompletedMatch] = []

    func loadAll() throws -> [CompletedMatch] { matches }
    func save(_ match: CompletedMatch) throws { matches.append(match) }
    func delete(id: UUID) throws { matches.removeAll { $0.id == id } }
    func wipeAll() throws { matches.removeAll() }
}
