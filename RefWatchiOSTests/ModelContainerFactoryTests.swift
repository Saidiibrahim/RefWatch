import XCTest
import SwiftData
@testable import RefWatchiOS
import RefWatchCore

private struct FailingBuilder: ModelContainerBuilding {
    func makePersistent(schema: Schema) throws -> ModelContainer { throw NSError(domain: "test", code: -1) }
    func makeInMemory(schema: Schema) throws -> ModelContainer { throw NSError(domain: "test", code: -2) }
}

private struct MemoryOnlyBuilder: ModelContainerBuilding {
    func makePersistent(schema: Schema) throws -> ModelContainer { throw NSError(domain: "test", code: -1) }
    func makeInMemory(schema: Schema) throws -> ModelContainer {
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }
}

final class ModelContainerFactoryTests: XCTestCase {
    func testFactory_fallsBackToInMemory_whenPersistentFails() throws {
        let schema = Schema([CompletedMatchRecord.self])
        let (container, store) = ModelContainerFactory.makeStore(builder: MemoryOnlyBuilder(), schema: schema)
        XCTAssertNotNil(container)
        XCTAssertTrue(store is SwiftDataMatchHistoryStore)
    }

    func testFactory_fallsBackToJSON_whenBothFail() throws {
        let schema = Schema([CompletedMatchRecord.self])
        let (container, store) = ModelContainerFactory.makeStore(builder: FailingBuilder(), schema: schema)
        XCTAssertNil(container)
        XCTAssertTrue(store is MatchHistoryService)
    }
}

