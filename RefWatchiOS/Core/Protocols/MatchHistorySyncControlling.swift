//
//  MatchHistorySyncControlling.swift
//  RefWatchiOS
//
//  Lightweight protocol so UI can trigger manual Supabase syncs without
//  depending on concrete repository types.
//

import Foundation

@MainActor
protocol MatchHistorySyncControlling: AnyObject {
  /// Requests an immediate Supabase sync. Returns `true` when a sync was
  /// scheduled, or `false` if the prerequisites (e.g. linked identity) are
  /// missing.
  func requestManualSync() -> Bool
}
