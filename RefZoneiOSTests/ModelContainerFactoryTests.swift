import XCTest
import SwiftData
@testable import RefZoneiOS
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
        let (container, store) = try ModelContainerFactory.makeStore(builder: MemoryOnlyBuilder(), schema: schema)
        XCTAssertEqual(container.configurations.first?.isStoredInMemoryOnly, true)
        XCTAssertTrue(store is SwiftDataMatchHistoryStore)
    }

    func testFactory_throws_whenAllBuildersFail() {
        let schema = Schema([CompletedMatchRecord.self])
        XCTAssertThrowsError(try ModelContainerFactory.makeStore(builder: FailingBuilder(), schema: schema)) { error in
            guard case ModelContainerFactory.Error.unableToCreateContainer = error else {
                XCTFail("Unexpected error thrown: \(error)")
                return
            }
        }
    }
}
