import XCTest
import SwiftData
@testable import RefWatchiOS
@testable import RefWatchCore

@MainActor
final class MatchForeignKeyIntegrationTests: XCTestCase {

    func testSwiftDataStorePersistsTeamIdentifiers() throws {
        let schema = Schema([CompletedMatchRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = SwiftDataMatchHistoryStore(container: container, auth: SignedInAuth())

        let homeId = UUID()
        let awayId = UUID()
        let competitionId = UUID()
        let venueId = UUID()

        var match = Match(homeTeam: "Arsenal", awayTeam: "Chelsea")
        match.homeTeamId = homeId
        match.awayTeamId = awayId
        match.competitionId = competitionId
        match.competitionName = "Premier League"
        match.venueId = venueId
        match.venueName = "Emirates Stadium"

        let snapshot = CompletedMatch(match: match, events: [])
        try store.save(snapshot)

        let record = try XCTUnwrap(store.fetchRecord(id: snapshot.id))
        XCTAssertEqual(record.homeTeamId, homeId)
        XCTAssertEqual(record.awayTeamId, awayId)
        XCTAssertEqual(record.competitionId, competitionId)
        XCTAssertEqual(record.competitionName, "Premier League")
        XCTAssertEqual(record.venueId, venueId)
        XCTAssertEqual(record.venueName, "Emirates Stadium")
    }

    func testCompletedMatchDecodesLegacyPayloadWithoutLinkingFields() throws {
        let json = """
        {
            "id": "f1c1b52d-8af7-4dca-8d64-14e9b27cf2a4",
            "completedAt": "2025-01-01T10:00:00Z",
            "match": {
                "id": "e4b36d26-7c12-441d-9c9c-9f9806dc1d8b",
                "homeTeam": "Arsenal",
                "awayTeam": "Chelsea",
                "duration": 5400,
                "numberOfPeriods": 2,
                "halfTimeLength": 900,
                "extraTimeHalfLength": 0,
                "hasExtraTime": false,
                "hasPenalties": false,
                "penaltyInitialRounds": 5,
                "homeScore": 2,
                "awayScore": 1,
                "homeYellowCards": 1,
                "awayYellowCards": 0,
                "homeRedCards": 0,
                "awayRedCards": 0,
                "homeSubs": 3,
                "awaySubs": 3
            },
            "events": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = Data(json.utf8)
        let snapshot = try decoder.decode(CompletedMatch.self, from: data)

        XCTAssertEqual(snapshot.match.homeTeam, "Arsenal")
        XCTAssertEqual(snapshot.match.awayTeam, "Chelsea")
        XCTAssertNil(snapshot.match.homeTeamId)
        XCTAssertNil(snapshot.match.awayTeamId)
        XCTAssertNil(snapshot.match.competitionId)
        XCTAssertNil(snapshot.match.venueId)
    }
}

private struct SignedInAuth: AuthenticationProviding {
    var state: AuthState { .signedIn(userId: "user-123", email: "user@example.com", displayName: "User") }
    var currentUserId: String? { "user-123" }
    var currentEmail: String? { "user@example.com" }
    var currentDisplayName: String? { "User" }
}
