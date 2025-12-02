#if os(watchOS)
import Foundation
import Observation
import WatchKit
@preconcurrency import RefWatchCore

/// Manages a single `WKExtendedRuntimeSession` so the match experience retains
/// quick-return affordances while the app is backgrounded or the screen is locked.
@MainActor
@Observable
final class BackgroundRuntimeSessionController: NSObject {
  enum Status {
    case idle
    case starting
    case running(startedAt: Date)
    case expiring(Date)
    case invalidated(reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?)
  }

  private(set) var status: Status = .idle
  private(set) var lastError: Error?
  private(set) var lastInvalidationReason: WKExtendedRuntimeSessionInvalidationReason?

  private var session: WKExtendedRuntimeSession?
  private var currentKind: BackgroundRuntimeActivityKind?
  private var currentTitle: String?
  private var currentMetadata: [String: String] = [:]
  private static var didValidateBackgroundModes = false
  private var restartAttempts = 0

  // MARK: - BackgroundRuntimeManaging

  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {
    currentKind = kind
    currentTitle = title
    currentMetadata = metadata
    restartAttempts = 0

    guard session?.state != .running else { return }
    startExtendedRuntimeSession()
  }

  func notifyPause() {
    // Intentionally keep the session running; we only mutate metadata so the
    // user activity payload can reflect the paused state in future iterations.
    currentMetadata["isPaused"] = "true"
  }

  func notifyResume() {
    currentMetadata["isPaused"] = "false"
  }

  func end(reason: BackgroundRuntimeEndReason) {
    currentKind = nil
    currentTitle = nil
    currentMetadata = [:]
    restartAttempts = 0
    status = .idle

    guard let session else { return }
    session.invalidate()
    self.session = nil
  }

  // MARK: - Private helpers

  private func startExtendedRuntimeSession() {
    cleanupExistingSession()
    #if DEBUG
    if !Self.didValidateBackgroundModes {
      Self.didValidateBackgroundModes = true
      let modes = Bundle.main.object(forInfoDictionaryKey: "WKBackgroundModes") as? [String] ?? []
      if modes.contains("workout-processing") == false {
        assertionFailure("WKBackgroundModes must include workout-processing for extended runtime quick return.")
      }
    }
    #endif
    let newSession = WKExtendedRuntimeSession()
    newSession.delegate = self
    session = newSession
    status = .starting
    newSession.start()
  }

  private func cleanupExistingSession() {
    if let session {
      session.delegate = nil
      session.invalidate()
    }
    session = nil
  }
}

extension BackgroundRuntimeSessionController: @MainActor BackgroundRuntimeManaging {}

// MARK: - WKExtendedRuntimeSessionDelegate

extension BackgroundRuntimeSessionController: WKExtendedRuntimeSessionDelegate {
  nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
    Task { @MainActor [weak self] in
      guard let self, extendedRuntimeSession === self.session else { return }
      self.status = .running(startedAt: Date())
      self.lastError = nil
      self.lastInvalidationReason = nil
    }
  }

  nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
    Task { @MainActor [weak self] in
      guard let self, extendedRuntimeSession === self.session else { return }
      self.status = .expiring(Date())
    }
  }

  nonisolated func extendedRuntimeSession(
    _ extendedRuntimeSession: WKExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    Task { @MainActor [weak self] in
      guard let self, extendedRuntimeSession === self.session else { return }
      self.status = .invalidated(reason: reason, error: error)
      self.lastError = error
      self.lastInvalidationReason = reason
      self.session = nil

      guard currentKind != nil else {
        status = .idle
        return
      }

      // Attempt a limited restart so we retain the quick-return affordance when
      // the system ends our session early (e.g., due to power or temperature).
      if restartAttempts < 2 {
        restartAttempts += 1
        startExtendedRuntimeSession()
      }
    }
  }
}
#endif
