//
//  ModelContainerFactory.swift
//  RefWatchiOS
//
//  Factory + builder protocol to construct SwiftData containers with
//  predictable fallback behavior. Enables unit testing of failure paths.
//

import Foundation
import SwiftData

protocol ModelContainerBuilding {
    func makePersistent(schema: Schema) throws -> ModelContainer
    func makeInMemory(schema: Schema) throws -> ModelContainer
}

struct DefaultModelContainerBuilder: ModelContainerBuilding {
    func makePersistent(schema: Schema) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [config])
    }
    func makeInMemory(schema: Schema) throws -> ModelContainer {
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [cfg])
    }
}

enum ModelContainerFactory {
    static func makeStore(builder: ModelContainerBuilding, schema: Schema) -> (ModelContainer?, MatchHistoryStoring) {
        if let persistent = try? builder.makePersistent(schema: schema) {
            return (persistent, SwiftDataMatchHistoryStore(container: persistent, auth: NoopAuth(), importJSONOnFirstRun: true))
        }
        if let memory = try? builder.makeInMemory(schema: schema) {
            return (memory, SwiftDataMatchHistoryStore(container: memory, auth: NoopAuth(), importJSONOnFirstRun: true))
        }
        // Final fallback
        return (nil, MatchHistoryService())
    }
}

