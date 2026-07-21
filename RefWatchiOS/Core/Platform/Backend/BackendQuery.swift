import Foundation

enum BackendQuery {
  /// A collection cursor must come from a completed collection pull, never a
  /// single-item push receipt. Supplying an explicit floor on first/relaunch
  /// pulls also asks the backend to include deletion tombstones.
  static let initialCollectionSyncFloor = Date(timeIntervalSince1970: 0)

  /// Collection writes are request-scoped, database-only transactions. Replay
  /// a deliberately generous window so a row whose timestamp was assigned
  /// before a blocked commit is still returned by a later pull. Strict local
  /// version checks make this overlap idempotent, while every relaunch still
  /// starts at `initialCollectionSyncFloor` for full tombstone reconciliation.
  static let collectionSafetyOverlap: TimeInterval = 15 * 60

  static func collectionPullCursor(from cursor: Date?) -> Date {
    let cursor = cursor ?? initialCollectionSyncFloor
    return max(
      initialCollectionSyncFloor,
      cursor.addingTimeInterval(-collectionSafetyOverlap))
  }

  static func shouldApplyCollectionRow(
    updatedAt remoteUpdatedAt: Date,
    over localUpdatedAt: Date?,
    localNeedsRemoteSync: Bool = false) -> Bool
  {
    guard !localNeedsRemoteSync else { return false }
    guard let localUpdatedAt else { return true }
    return remoteUpdatedAt > localUpdatedAt
  }

  static func updatedAfter(_ date: Date?) -> [URLQueryItem] {
    guard let date else { return [] }
    return [URLQueryItem(name: "updatedAfter", value: ISO8601DateFormatter().string(from: date))]
  }
}
