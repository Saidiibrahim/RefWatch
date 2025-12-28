//
//  CompetitionLibraryStoring.swift
//  RefWatchiOS
//
//  Protocol for local persistence of competition library.
//  Enables dependency injection and test mocking.
//

import Foundation
import Combine

/// Protocol for storing and retrieving competitions locally
protocol CompetitionLibraryStoring: AnyObject {
    /// Publisher that emits when competitions change
    var changesPublisher: AnyPublisher<[CompetitionRecord], Never> { get }

    /// Load all competitions
    func loadAll() throws -> [CompetitionRecord]

    /// Search competitions by name
    /// - Parameter query: Search term (case-insensitive substring match)
    func search(query: String) throws -> [CompetitionRecord]

    /// Create a new competition
    /// - Parameters:
    ///   - name: Competition name (required)
    ///   - level: Competition level/tier (optional)
    /// - Returns: The created competition record
    func create(name: String, level: String?) throws -> CompetitionRecord

    /// Update an existing competition
    /// - Parameter competition: The competition to update
    func update(_ competition: CompetitionRecord) throws

    /// Delete a competition
    /// - Parameter competition: The competition to delete
    func delete(_ competition: CompetitionRecord) throws

    /// Wipe all competitions (used on sign-out)
    func wipeAllForLogout() throws

    /// Pull the latest competitions from the remote source
    func refreshFromRemote() async throws
}
