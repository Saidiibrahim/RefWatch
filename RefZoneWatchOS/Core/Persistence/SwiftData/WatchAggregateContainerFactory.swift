//
//  WatchAggregateContainerFactory.swift
//  RefZoneWatchOS
//
//  Builds SwiftData containers for aggregate sync storage on watchOS.
//

import SwiftData

enum WatchAggregateContainerFactory {
  enum FactoryError: Swift.Error {
    case unableToCreateContainer
  }

  @MainActor
  static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
    let schema = WatchAggregateModelSchema.schema
    let configuration = ModelConfiguration(
      schema: schema,
      isStoredInMemoryOnly: inMemory
    )
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  @MainActor
  static func makeBestEffortContainer() throws -> ModelContainer {
    do {
      return try makeContainer()
    } catch {
      if let memory = try? makeContainer(inMemory: true) {
        return memory
      }
      throw FactoryError.unableToCreateContainer
    }
  }
}
