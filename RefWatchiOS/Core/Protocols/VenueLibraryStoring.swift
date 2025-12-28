//
//  VenueLibraryStoring.swift
//  RefWatchiOS
//
//  Protocol for local persistence of venue library.
//  Enables dependency injection and test mocking.
//

import Foundation
import Combine

/// Protocol for storing and retrieving venues locally
protocol VenueLibraryStoring: AnyObject {
    /// Publisher that emits when venues change
    var changesPublisher: AnyPublisher<[VenueRecord], Never> { get }

    /// Load all venues
    func loadAll() throws -> [VenueRecord]

    /// Search venues by name, city, or country
    /// - Parameter query: Search term (case-insensitive substring match)
    func search(query: String) throws -> [VenueRecord]

    /// Create a new venue
    /// - Parameters:
    ///   - name: Venue name (required)
    ///   - city: City (optional)
    ///   - country: Country (optional)
    /// - Returns: The created venue record
    func create(name: String, city: String?, country: String?) throws -> VenueRecord

    /// Update an existing venue
    /// - Parameter venue: The venue to update
    func update(_ venue: VenueRecord) throws

    /// Delete a venue
    /// - Parameter venue: The venue to delete
    func delete(_ venue: VenueRecord) throws

    /// Wipe all venues (used on sign-out)
    func wipeAllForLogout() throws

    /// Pull the latest venues from the remote source
    func refreshFromRemote() async throws
}
