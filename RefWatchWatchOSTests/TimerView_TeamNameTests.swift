import Testing
@testable import RefWatch_Watch_App
@testable import RefWatchCore

@MainActor
@Suite("TimerView Team Names")
struct TimerViewTeamNameTests {

    @Test("Uses currentMatch team names after start")
    func usesCurrentMatchNames() async {
        let viewModel = MatchViewModel(history: InMemoryHistory())

        var match = Match(id: UUID(), homeTeam: "Manchester United", awayTeam: "Liverpool")
        viewModel.currentMatch = match
        viewModel.startMatch()

        #expect(viewModel.homeTeamDisplayName == "Manchester United")
        #expect(viewModel.awayTeamDisplayName == "Liverpool")

        #expect(viewModel.homeTeam != "Manchester United")
        #expect(viewModel.awayTeam != "Liverpool")
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
