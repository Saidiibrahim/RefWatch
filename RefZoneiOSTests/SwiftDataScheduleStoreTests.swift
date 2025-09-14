#if canImport(XCTest)
import XCTest
import SwiftData
@testable import RefZoneiOS

final class SwiftDataScheduleStoreTests: XCTestCase {

    func makeMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ScheduledMatchRecord.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    func test_crud_roundtrip() throws {
        let container = try makeMemoryContainer()
        let store = SwiftDataScheduleStore(container: container, importJSONOnFirstRun: false)
        // Clean slate
        store.wipeAll()

        let kickoff = Date().addingTimeInterval(3600)
        let item = ScheduledMatch(homeTeam: "Home", awayTeam: "Away", kickoff: kickoff)
        store.save(item)

        let all = store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.homeTeam, "Home")

        // Update
        var updated = all[0]
        updated.homeTeam = "Hosts"
        store.save(updated)
        let again = store.loadAll()
        XCTAssertEqual(again.first?.homeTeam, "Hosts")

        // Delete
        store.delete(id: updated.id)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    func test_import_from_legacy_json() throws {
        // Reset flag before creating store
        UserDefaults.standard.removeObject(forKey: "rw_schedule_imported_v1")

        // Write a legacy JSON file to the documents directory
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            XCTFail("No documents directory available")
            return
        }
        let url = docs.appendingPathComponent("scheduled_matches.json")
        let samples = [ScheduledMatch(homeTeam: "Alpha", awayTeam: "Beta", kickoff: Date())]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(samples)
        try data.write(to: url, options: .atomic)

        let container = try makeMemoryContainer()
        let store = SwiftDataScheduleStore(container: container, importJSONOnFirstRun: true)
        let all = store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.homeTeam, "Alpha")
    }
}

#endif

