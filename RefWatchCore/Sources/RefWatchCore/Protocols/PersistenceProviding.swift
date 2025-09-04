//
//  PersistenceProviding.swift
//  RefWatchCore
//
//  Abstraction for storing/loading completed matches (future SwiftData on iOS)
//

import Foundation

public protocol PersistenceProviding {
    func loadAllCompleted() throws -> [CompletedMatch]
    func saveCompleted(_ match: CompletedMatch) throws
    func deleteCompleted(id: UUID) throws
}

