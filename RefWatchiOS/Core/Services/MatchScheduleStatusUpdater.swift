//
//  MatchScheduleStatusUpdater.swift
//  RefWatchiOS
//
//  iOS implementation of schedule status updating when matches are finalized.
//

import Foundation
import OSLog
import RefWatchCore

/// iOS implementation that marks scheduled matches as completed when finalized.
///
/// When a match is completed on iOS, this updater locates the corresponding
/// schedule record and updates its status to `.completed`, ensuring it no
/// longer appears in the watch "Select Match" list or iOS "Upcoming" section.
@MainActor
final class MatchScheduleStatusUpdater: MatchScheduleStatusUpdating {
  private let scheduleStore: ScheduleStoring

  init(scheduleStore: ScheduleStoring) {
    self.scheduleStore = scheduleStore
  }

  func markScheduleInProgress(scheduledId: UUID) async throws {
    // Find schedule and flip to in_progress for immediate UI/watch consistency
    let schedules = self.scheduleStore.loadAll()
    guard var schedule = schedules.first(where: { $0.id == scheduledId }) else {
      #if DEBUG
      AppLog.connectivity.debug(
        "No schedule found for \(scheduledId.uuidString, privacy: .public) - skipping in-progress update")
      #endif
      return
    }
    schedule.status = .inProgress
    try self.scheduleStore.save(schedule)
    #if DEBUG
    AppLog.connectivity.debug("➡️ Marked schedule \(scheduledId.uuidString, privacy: .public) as in_progress")
    #endif
  }

  func markScheduleCompleted(scheduledId: UUID) async throws {
    // Load all schedules and find the one matching the schedule ID
    let schedules = self.scheduleStore.loadAll()
    guard var schedule = schedules.first(where: { $0.id == scheduledId }) else {
      // Schedule not found - this is OK for manually created matches that
      // were never scheduled through the library system
      #if DEBUG
      AppLog.connectivity.debug(
        "No schedule found for \(scheduledId.uuidString, privacy: .public) - likely manual match; skipping status update")
      NotificationCenter.default.post(
        name: .syncFallbackOccurred,
        object: nil,
        userInfo: [
          "context": "ios.scheduleUpdater.notFound",
          "scheduledId": scheduledId.uuidString,
        ])
      #endif
      return
    }

    // Update status to completed and save
    schedule.status = .completed
    try self.scheduleStore.save(schedule)

    #if DEBUG
    AppLog.connectivity.debug("✅ Marked schedule \(scheduledId.uuidString, privacy: .public) as completed")
    #endif
  }
}
