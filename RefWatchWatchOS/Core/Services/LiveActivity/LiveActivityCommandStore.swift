//
//  LiveActivityCommandStore.swift
//  RefWatchWatchOS
//
//  Persists the most recent LiveActivity command issued from App Intents
//  so the watch app can consume and execute it.
//

import Foundation

// MARK: - LiveActivityCommandStoring

protocol LiveActivityCommandStoring {
  @discardableResult
  func write(_ command: LiveActivityCommand) -> LiveActivityCommandEnvelope
  func consume() -> LiveActivityCommandEnvelope?
  func clear()
}

// MARK: - LiveActivityCommandStore

final class LiveActivityCommandStore: LiveActivityCommandStoring {
  static let defaultCommandKey = "liveActivity.command.v1"

  private let suiteName: String
  private let defaults: UserDefaults?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(suiteName: String = LiveActivityStateStore.defaultAppGroupId) {
    self.suiteName = suiteName
    self.defaults = UserDefaults(suiteName: suiteName)
  }

  // MARK: - API

  @discardableResult
  func write(_ command: LiveActivityCommand) -> LiveActivityCommandEnvelope {
    let envelope = LiveActivityCommandEnvelope(command: command)
    guard let defaults else { return envelope }
    do {
      let data = try encoder.encode(envelope)
      defaults.set(data, forKey: Self.defaultCommandKey)
    } catch {
      #if DEBUG
      print("LiveActivityCommandStore.write encoding failed: \(error)")
      #endif
    }
    return envelope
  }

  func consume() -> LiveActivityCommandEnvelope? {
    guard let defaults else { return nil }
    guard let data = defaults.data(forKey: Self.defaultCommandKey) else { return nil }
    do {
      let envelope = try decoder.decode(LiveActivityCommandEnvelope.self, from: data)
      defaults.removeObject(forKey: Self.defaultCommandKey)
      return envelope
    } catch {
      #if DEBUG
      print("LiveActivityCommandStore.consume decoding failed: \(error)")
      #endif
      defaults.removeObject(forKey: Self.defaultCommandKey)
      return nil
    }
  }

  func clear() {
    guard let defaults else { return }
    defaults.removeObject(forKey: Self.defaultCommandKey)
  }
}
