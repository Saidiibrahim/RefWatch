//
//  Notifications+SyncDiagnostics.swift
//  RefWatchCore
//
//  DEBUG-only notification names for observing connectivity sync behavior
//  during development. These are posted on the main thread.
//

import Foundation

extension Notification.Name {
  /// Posted when a recoverable connectivity issue occurs and the client
  /// falls back to a durable transfer mechanism (e.g., sendMessage → transferUserInfo).
  /// userInfo may include: ["context": String]
  public static let syncFallbackOccurred = Notification.Name("SyncFallbackOccurred")

  /// Posted when a non-recoverable sync error is detected (e.g., encoding/decoding
  /// failure, session unsupported). Default behavior is still to continue silently
  /// in release builds; consumers may observe this in DEBUG for diagnostics.
  /// userInfo may include: ["error": String, "context": String]
  public static let syncNonrecoverableError = Notification.Name("SyncNonrecoverableError")

  /// Posted when repositories publish a status snapshot (pending counts,
  /// retry windows, auth state).
  /// userInfo: ["component": String, "pendingPushes": Int,
  /// "pendingDeletions": Int, "signedIn": Bool, "nextRetry": Date?,
  /// "timestamp": Date]
  public static let syncStatusUpdate = Notification.Name("SyncStatusUpdate")
}
