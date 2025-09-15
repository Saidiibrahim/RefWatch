//
//  LiveActivityStateStore.swift
//  RefZoneWatchOS
//
//  Persists the latest LiveActivityState in App Group UserDefaults.
//  The widget extension reads from the same suite to render timelines.
//

import Foundation

// MARK: - LiveActivityStateStore

final class LiveActivityStateStore {
  // Default App Group suite; adjust if project settings differ
  static let defaultAppGroupId = "group.refzone.shared"

  private let suiteName: String
  private let defaults: UserDefaults?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(suiteName: String = LiveActivityStateStore.defaultAppGroupId) {
    self.suiteName = suiteName
    self.defaults = UserDefaults(suiteName: suiteName)
  }

  // MARK: - API

  func write(_ state: LiveActivityState) {
    guard let defaults else { return }
    do {
      let data = try encoder.encode(state)
      defaults.set(data, forKey: LiveActivityState.storeKeyV1)
      defaults.synchronize()
    } catch {
      #if DEBUG
      print("LiveActivityStateStore.write encoding failed: \(error)")
      #endif
    }
  }

  func read() -> LiveActivityState? {
    guard let defaults else { return nil }
    guard let data = defaults.data(forKey: LiveActivityState.storeKeyV1) else { return nil }
    do {
      return try decoder.decode(LiveActivityState.self, from: data)
    } catch {
      #if DEBUG
      print("LiveActivityStateStore.read decoding failed: \(error)")
      #endif
      return nil
    }
  }

  func clear() {
    guard let defaults else { return }
    defaults.removeObject(forKey: LiveActivityState.storeKeyV1)
    defaults.synchronize()
  }
}
