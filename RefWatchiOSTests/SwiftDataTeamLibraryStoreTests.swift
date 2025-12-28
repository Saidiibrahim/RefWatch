#if canImport(XCTest)
import XCTest
import SwiftData
@testable import RefWatchiOS
import RefWatchCore

private struct AuthStub: AuthenticationProviding {
    var userId: String?
    var state: AuthState {
        if let userId {
            return .signedIn(userId: userId, email: nil, displayName: nil)
        }
        return .signedOut
    }
    var currentUserId: String? { userId }
    var currentEmail: String? { nil }
    var currentDisplayName: String? { nil }
}

@MainActor
final class SwiftDataTeamLibraryStoreTests: XCTestCase {

    func makeMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TeamRecord.self, PlayerRecord.self, TeamOfficialRecord.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    func test_team_crud_and_nested_entities() throws {
        let container = try makeMemoryContainer()
        let userId = UUID().uuidString
        let store = SwiftDataTeamLibraryStore(container: container, auth: AuthStub(userId: userId))

        // Create team
        let team = try store.createTeam(name: "Leeds United", shortName: "LEE", division: "U18")
        var all = try store.loadAllTeams()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Leeds United")
        XCTAssertTrue(team.needsRemoteSync)
        XCTAssertEqual(team.ownerSupabaseId, userId)

        // Update team
        team.name = "Leeds"
        try store.updateTeam(team)
        all = try store.loadAllTeams()
        XCTAssertEqual(all.first?.name, "Leeds")
        XCTAssertTrue(team.needsRemoteSync)

        // Add player
        let p = try store.addPlayer(to: team, name: "John Smith", number: 9)
        XCTAssertEqual(team.players.count, 1)
        XCTAssertEqual(p.team?.id, team.id)
        XCTAssertTrue(team.needsRemoteSync)

        // Edit player
        p.name = "Jon Smith"; p.number = 10
        try store.updatePlayer(p)
        XCTAssertEqual(team.players.first?.number, 10)
        XCTAssertTrue(team.needsRemoteSync)

        // Add official
        let o = try store.addOfficial(to: team, name: "Coach Bob", roleRaw: "Coach")
        XCTAssertEqual(team.officials.count, 1)
        XCTAssertEqual(o.team?.id, team.id)
        XCTAssertTrue(team.needsRemoteSync)

        // Edit official
        o.name = "Coach Robert"
        try store.updateOfficial(o)
        XCTAssertEqual(team.officials.first?.name, "Coach Robert")
        XCTAssertTrue(team.needsRemoteSync)

        // Search
        let results = try store.searchTeams(query: "Lee")
        XCTAssertEqual(results.count, 1)

        // Delete nested
        try store.deletePlayer(p)
        XCTAssertEqual(team.players.count, 0)
        try store.deleteOfficial(o)
        XCTAssertEqual(team.officials.count, 0)
        XCTAssertTrue(team.needsRemoteSync)

        // Delete team
        try store.deleteTeam(team)
        all = try store.loadAllTeams()
        XCTAssertEqual(all.count, 0)
    }

    func test_createTeam_signedOutThrows() throws {
        let container = try makeMemoryContainer()
        let store = SwiftDataTeamLibraryStore(container: container, auth: AuthStub(userId: nil))
        XCTAssertThrowsError(try store.createTeam(name: "Test", shortName: nil, division: nil)) { error in
            guard case PersistenceAuthError.signedOut = error else {
                XCTFail("Expected signed-out persistence error, got: \(error)")
                return
            }
        }
    }
}

#endif
