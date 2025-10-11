//
//  MatchEventConfirmation.swift
//  RefWatchCore
//
//  Lightweight model describing a transient event confirmation state.
//

import Foundation

/// Represents a recently recorded, user-driven match event that should surface
/// a confirmation UI.
public struct MatchEventConfirmation: Identifiable {
    public let id: UUID
    public let event: MatchEventRecord
    public let createdAt: Date

    public init(event: MatchEventRecord, createdAt: Date = Date()) {
        self.id = UUID()
        self.event = event
        self.createdAt = createdAt
    }
}
