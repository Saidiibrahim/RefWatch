//
//  PersistedActiveMatchSessionStore.swift
//  RefWatchWatchOS
//
//  Description: App Group-backed persistence for unfinished-match snapshots
//  used during watch relaunch and workout recovery flows.
//

import Foundation
import RefWatchCore

/// Stores the current unfinished-match snapshot in the watch App Group so Match
/// Mode can restore directly into the interrupted lifecycle state on relaunch.
final class PersistedActiveMatchSessionStore: ActiveMatchSessionStoring {
  private static let storeKey = "active_match_session_snapshot_v1"
  private static let uiTestSnapshotEnvKey = "REFWATCH_ACTIVE_MATCH_SNAPSHOT_BASE64"
  private static let uiTestProcessEnvKey = "REFWATCH_UI_TEST_PROCESS"
  private static let uiTestLaunchArgument = "--refwatch-ui-testing"
  private static let defaultAppGroupId: String = {
    Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String ?? "group.refwatch.shared"
  }()

  private let defaults: UserDefaults?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(suiteName: String? = nil) {
    let resolvedSuiteName = suiteName ?? Self.defaultAppGroupId
    self.defaults = UserDefaults(suiteName: resolvedSuiteName) ?? .standard
  }

  func load() throws -> ActiveMatchSessionSnapshot? {
    if Self.isRunningUITests,
       let encodedSnapshot = ProcessInfo.processInfo.environment[Self.uiTestSnapshotEnvKey],
       let data = Data(base64Encoded: encodedSnapshot)
    {
      return try self.decoder.decode(ActiveMatchSessionSnapshot.self, from: data)
    }
    if Self.isRunningUITests {
      // Each UI test starts from idle unless it explicitly supplies a restore
      // fixture. This prevents an unfinished match from one process launch from
      // contaminating the next test while preserving production recovery.
      try self.clear()
      return nil
    }
    guard let data = self.defaults?.data(forKey: Self.storeKey) else { return nil }
    return try self.decoder.decode(ActiveMatchSessionSnapshot.self, from: data)
  }

  func save(_ snapshot: ActiveMatchSessionSnapshot) throws {
    let data = try self.encoder.encode(snapshot)
    self.defaults?.set(data, forKey: Self.storeKey)
  }

  func clear() throws {
    self.defaults?.removeObject(forKey: Self.storeKey)
  }

  private static var isRunningUITests: Bool {
    let process = ProcessInfo.processInfo
    return process.environment[Self.uiTestProcessEnvKey] == "1"
      && process.arguments.contains(Self.uiTestLaunchArgument)
  }
}
