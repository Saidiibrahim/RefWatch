#if canImport(XCTest)
import XCTest
import SwiftData
import Combine
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
final class SwiftDataScheduleStoreTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func makeMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ScheduledMatchRecord.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    func test_crud_roundtrip() throws {
        let container = try makeMemoryContainer()
        let store = SwiftDataScheduleStore(container: container, auth: AuthStub(userId: UUID().uuidString))
        // Clean slate
        try store.wipeAll()

        let kickoff = Date().addingTimeInterval(3600)
        let item = ScheduledMatch(homeTeam: "Home", awayTeam: "Away", kickoff: kickoff)
        try store.save(item)

        let all = store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.homeTeam, "Home")

        // Update
        var updated = all[0]
        updated.homeTeam = "Hosts"
        try store.save(updated)
        let again = store.loadAll()
        XCTAssertEqual(again.first?.homeTeam, "Hosts")

        // Delete
        try store.delete(id: updated.id)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func test_changesPublisher_emitsUpdates() throws {
        let container = try makeMemoryContainer()
        let store = SwiftDataScheduleStore(container: container, auth: AuthStub(userId: UUID().uuidString))

        let expectation = expectation(description: "publisher emits")
        expectation.expectedFulfillmentCount = 2 // Initial snapshot + save

        store.changesPublisher
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        try store.save(ScheduledMatch(homeTeam: "Home", awayTeam: "Away", kickoff: Date()))

        wait(for: [expectation], timeout: 1.0)
    }

    func testSaveSignedOut_throwsAuthError() throws {
        let container = try makeMemoryContainer()
        let store = SwiftDataScheduleStore(container: container, auth: AuthStub(userId: nil))
        let match = ScheduledMatch(homeTeam: "Home", awayTeam: "Away", kickoff: Date())
        XCTAssertThrowsError(try store.save(match)) { error in
            guard case PersistenceAuthError.signedOut = error else {
                XCTFail("Expected signed-out persistence error, got: \(error)")
                return
            }
        }
    }
}

#endif
