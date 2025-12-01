import Testing
@testable import RefZoneiOS
import RefWatchCore

@Suite("MatchesTabView Filtering")
struct MatchesTabViewFilterTests {

    @Test("Excludes completed from upcoming")
    func excludesCompletedFromUpcoming() {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let startOfTomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let futureKickoff = startOfTomorrow.addingTimeInterval(3_600)

        let scheduled = ScheduledMatch(
            id: UUID(),
            homeTeam: "A",
            awayTeam: "B",
            kickoff: futureKickoff,
            status: .scheduled
        )
        let completed = ScheduledMatch(
            id: UUID(),
            homeTeam: "C",
            awayTeam: "D",
            kickoff: futureKickoff,
            status: .completed
        )

        let partitions = MatchesTabView.partitionSchedules([scheduled, completed], now: now, calendar: calendar)

        #expect(partitions.upcoming.count == 1)
        #expect(partitions.upcoming.first?.homeTeam == "A")
    }

    @Test("Retains in-progress in today")
    func retainsInProgressInToday() {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let midday = calendar.startOfDay(for: now).addingTimeInterval(12 * 60 * 60)

        let inProgress = ScheduledMatch(
            id: UUID(),
            homeTeam: "Live A",
            awayTeam: "Live B",
            kickoff: midday,
            status: .inProgress
        )
        let completed = ScheduledMatch(
            id: UUID(),
            homeTeam: "Done A",
            awayTeam: "Done B",
            kickoff: midday,
            status: .completed
        )

        let partitions = MatchesTabView.partitionSchedules([inProgress, completed], now: now, calendar: calendar)

        #expect(partitions.today.count == 1)
        #expect(partitions.today.first?.status == .inProgress)
    }
}
