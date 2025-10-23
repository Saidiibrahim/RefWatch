//
//  MatchScheduleStatusUpdating.swift
//  RefWatchCore
//
//  Cross-platform protocol for updating schedule status when matches are finalized.
//  iOS provides a real implementation; watchOS passes nil.
//

import Foundation

/// Protocol for updating scheduled match status when a match is completed.
///
/// This protocol enables iOS to mark scheduled matches as completed when
/// they are finalized, ensuring that completed matches no longer appear
/// in the watch "Select Match" list or iOS "Upcoming" section.
///
/// watchOS implementations pass `nil` since the watch doesn't manage
/// schedule persistence directly.
@MainActor
public protocol MatchScheduleStatusUpdating {
    /// Marks a scheduled match as in-progress.
    ///
    /// - Parameter scheduledId: The UUID of the schedule (not the match) to mark as in progress.
    /// - Throws: An error if the schedule cannot be found or updated.
    func markScheduleInProgress(scheduledId: UUID) async throws

    /// Marks a scheduled match as completed.
    ///
    /// - Parameter scheduledId: The UUID of the schedule (not the match) to mark as completed.
    /// - Throws: An error if the schedule cannot be found or updated.
    func markScheduleCompleted(scheduledId: UUID) async throws
}
