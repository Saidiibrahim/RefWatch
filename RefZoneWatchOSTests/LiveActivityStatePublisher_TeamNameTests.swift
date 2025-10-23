import Testing
@testable import RefZone_Watch_App
@testable import RefWatchCore

@MainActor
@Suite("LiveActivityStatePublisher Team Names")
struct LiveActivityStatePublisherTeamNameTests {

    @Test("Uses currentMatch names in derived state")
    func usesCurrentMatchNames() async {
        let viewModel = MatchViewModel(history: InMemoryHistory())
        let publisher = LiveActivityStatePublisher()

        var match = Match(id: UUID(), homeTeam: "Real Madrid", awayTeam: "Barcelona")
        viewModel.currentMatch = match
        viewModel.startMatch()

        let state = publisher.deriveState(from: viewModel)

        #expect(state?.homeAbbr == "Real Madrid")
        #expect(state?.awayAbbr == "Barcelona")
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
