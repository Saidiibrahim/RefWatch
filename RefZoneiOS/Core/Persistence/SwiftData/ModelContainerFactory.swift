//
//  ModelContainerFactory.swift
//  RefWatchiOS
//
//  Factory + builder protocol to construct SwiftData containers with
//  predictable fallback behavior. Enables unit testing of failure paths.
//

import Foundation
import SwiftData
import RefWatchCore

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
    /// Builds a SwiftData container and returns a tuple of (container, history store).
    /// The provided `auth` is threaded into the SwiftData-backed store so that
    /// owner identity can be attached on save. In failure fallbacks, the JSON
    /// store is returned which does not use auth (best-effort continuity).
    @MainActor
    static func makeStore(
        builder: ModelContainerBuilding,
        schema: Schema,
        auth: AuthenticationProviding = NoopAuth()
    ) -> (ModelContainer?, MatchHistoryStoring) {
        if let persistent = try? builder.makePersistent(schema: schema) {
            return (persistent, SwiftDataMatchHistoryStore(container: persistent, auth: auth, importJSONOnFirstRun: true))
        }
        if let memory = try? builder.makeInMemory(schema: schema) {
            return (memory, SwiftDataMatchHistoryStore(container: memory, auth: auth, importJSONOnFirstRun: true))
        }
        // Final fallback
        return (nil, MatchHistoryService())
    }
}
