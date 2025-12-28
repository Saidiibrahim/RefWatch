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
    enum Error: Swift.Error {
        case unableToCreateContainer
    }

    /// Builds a SwiftData container and returns a tuple of (container, SwiftData-backed history store).
    /// The provided `auth` is threaded into the store so that owner identity can be attached on save.
    @MainActor
    static func makeStore(
        builder: ModelContainerBuilding,
        schema: Schema,
        auth: AuthenticationProviding = NoopAuth()
    ) throws -> (ModelContainer, SwiftDataMatchHistoryStore) {
        if let persistent = try? builder.makePersistent(schema: schema) {
            return (persistent, SwiftDataMatchHistoryStore(container: persistent, auth: auth))
        }
        if let memory = try? builder.makeInMemory(schema: schema) {
            return (memory, SwiftDataMatchHistoryStore(container: memory, auth: auth))
        }
        throw Error.unableToCreateContainer
    }
}
