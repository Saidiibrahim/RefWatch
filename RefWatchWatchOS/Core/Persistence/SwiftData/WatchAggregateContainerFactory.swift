//
//  WatchAggregateContainerFactory.swift
//  RefWatchWatchOS
//
//  Builds SwiftData containers for aggregate sync storage on watchOS.
//

import Foundation
import SwiftData

enum WatchAggregateContainerFactory {
  enum FactoryError: Swift.Error {
    case unableToCreateContainer
    case appGroupContainerNotFound
  }

  private static let appGroupId: String = {
    Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String ?? "group.refwatch.shared"
  }()

  private static func storeURL() throws -> URL {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else {
      throw FactoryError.appGroupContainerNotFound
    }

    let applicationSupportURL = containerURL
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Application Support", isDirectory: true)

    try FileManager.default.createDirectory(
      at: applicationSupportURL,
      withIntermediateDirectories: true
    )

    return applicationSupportURL.appendingPathComponent("default.store")
  }

  @MainActor
  static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
    let schema = WatchAggregateModelSchema.schema

    if inMemory {
      let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
      )
      return try ModelContainer(for: schema, configurations: [configuration])
    }

    let url = try storeURL()
    let configuration = ModelConfiguration(
      schema: schema,
      url: url,
      allowsSave: true,
      cloudKitDatabase: .none
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
