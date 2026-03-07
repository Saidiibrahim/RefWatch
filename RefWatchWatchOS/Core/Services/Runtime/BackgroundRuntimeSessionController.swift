#if os(watchOS)
import Foundation
import Observation
import WatchKit
@preconcurrency import RefWatchCore

@MainActor
protocol ExtendedRuntimeSessionDelegate: AnyObject {
  func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: any ExtendedRuntimeSession)
  func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: any ExtendedRuntimeSession)
  func extendedRuntimeSession(
    _ extendedRuntimeSession: any ExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?)
}

@MainActor
protocol ExtendedRuntimeSession: AnyObject {
  var delegate: (any ExtendedRuntimeSessionDelegate)? { get set }
  var state: WKExtendedRuntimeSessionState { get }
  func start()
  func invalidate()
}

@MainActor
private final class WatchKitExtendedRuntimeSession: NSObject, ExtendedRuntimeSession {
  private let session: WKExtendedRuntimeSession
  weak var delegate: (any ExtendedRuntimeSessionDelegate)?

  init(session: WKExtendedRuntimeSession = WKExtendedRuntimeSession()) {
    self.session = session
    super.init()
    self.session.delegate = self
  }

  var state: WKExtendedRuntimeSessionState {
    self.session.state
  }

  func start() {
    self.session.start()
  }

  func invalidate() {
    self.session.invalidate()
  }
}

extension WatchKitExtendedRuntimeSession: WKExtendedRuntimeSessionDelegate {
  nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.delegate?.extendedRuntimeSessionDidStart(self)
    }
  }

  nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.delegate?.extendedRuntimeSessionWillExpire(self)
    }
  }

  nonisolated func extendedRuntimeSession(
    _ extendedRuntimeSession: WKExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      self.delegate?.extendedRuntimeSession(self, didInvalidateWith: reason, error: error)
    }
  }
}

/// Manages a single `WKExtendedRuntimeSession` so the match experience retains
/// quick-return affordances while the app is backgrounded or the screen is locked.
@MainActor
@Observable
final class BackgroundRuntimeSessionController: NSObject {
  typealias SessionFactory = @MainActor () -> any ExtendedRuntimeSession

  private enum StartTrigger {
    case begin
    case proactiveRenewal
    case invalidation(WKExtendedRuntimeSessionInvalidationReason)

    var logName: String {
      switch self {
      case .begin:
        return "begin"
      case .proactiveRenewal:
        return "proactive-renewal"
      case let .invalidation(reason):
        return "invalidation-\(reason.rawValue)"
      }
    }
  }

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

  private let sessionFactory: SessionFactory
  private let isAppActiveProvider: @MainActor () -> Bool
  private let maxConsecutiveStartFailures: Int

  private var session: (any ExtendedRuntimeSession)?
  private var currentKind: BackgroundRuntimeActivityKind?
  private var currentTitle: String?
  private var currentMetadata: [String: String] = [:]
  private static var didValidateBackgroundModes = false
  private var consecutiveStartFailures = 0
  private var renewalTimer: Timer?

  /// Self-care sessions grant ~10 minutes; renew proactively before expiry.
  private static let selfCareSessionDurationSeconds: TimeInterval = 600
  private static let renewalLeadTimeSeconds: TimeInterval = 30
  private static let minimumRenewalIntervalSeconds: TimeInterval = 60

  init(
    sessionFactory: @escaping SessionFactory = { WatchKitExtendedRuntimeSession() },
    isAppActiveProvider: @escaping @MainActor () -> Bool = {
      WKExtension.shared().applicationState == .active
    },
    maxConsecutiveStartFailures: Int = 3
  ) {
    self.sessionFactory = sessionFactory
    self.isAppActiveProvider = isAppActiveProvider
    self.maxConsecutiveStartFailures = maxConsecutiveStartFailures
    super.init()
  }

  // MARK: - BackgroundRuntimeManaging

  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {
    self.currentKind = kind
    self.currentTitle = title
    self.currentMetadata = metadata
    self.consecutiveStartFailures = 0

    guard self.session?.state != .running else {
      self.log("begin() ignored because session already running")
      return
    }
    self.startExtendedRuntimeSession(trigger: .begin)
  }

  func notifyPause() {
    // Intentionally keep the session running; we only mutate metadata so the
    // user activity payload can reflect the paused state in future iterations.
    self.currentMetadata["isPaused"] = "true"
  }

  func notifyResume() {
    self.currentMetadata["isPaused"] = "false"
  }

  func end(reason: BackgroundRuntimeEndReason) {
    self.currentKind = nil
    self.currentTitle = nil
    self.currentMetadata = [:]
    self.consecutiveStartFailures = 0
    self.status = .idle
    self.log("end(reason: \(reason))")
    self.cleanupExistingSession()
  }

  // MARK: - Private helpers

  private func startExtendedRuntimeSession(trigger: StartTrigger) {
    guard self.currentKind != nil else { return }
    guard self.canStartRuntimeSession(for: trigger) else {
      self.log("deferred runtime start (\(trigger.logName)) because app is not active")
      return
    }

    self.cleanupExistingSession()
    #if DEBUG
    if !Self.didValidateBackgroundModes {
      Self.didValidateBackgroundModes = true
      let modes = Bundle.main.object(forInfoDictionaryKey: "WKBackgroundModes") as? [String] ?? []
      if modes.contains("self-care") == false {
        assertionFailure("WKBackgroundModes must include self-care for extended runtime session chaining.")
      }
    }
    #endif
    let newSession = self.sessionFactory()
    newSession.delegate = self
    self.session = newSession
    self.status = .starting
    self.log("starting runtime session (trigger: \(trigger.logName))")
    newSession.start()
  }

  private func cleanupExistingSession() {
    self.cancelRenewalTimer()
    if let session = self.session {
      session.delegate = nil
      session.invalidate()
    }
    self.session = nil
  }

  private func cancelRenewalTimer() {
    self.renewalTimer?.invalidate()
    self.renewalTimer = nil
  }

  var hasScheduledRenewalTimerForTesting: Bool {
    self.renewalTimer != nil
  }

  private func scheduleRenewalTimer() {
    self.cancelRenewalTimer()
    let interval = max(
      Self.selfCareSessionDurationSeconds - Self.renewalLeadTimeSeconds,
      Self.minimumRenewalIntervalSeconds)
    self.renewalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.performProactiveRenewal()
      }
    }
  }

  private func performProactiveRenewal() {
    guard self.currentKind != nil else { return }
    guard self.canStartRuntimeSession(for: .proactiveRenewal) else {
      self.log("proactive renewal skipped -- app not active")
      return
    }
    self.log("proactive renewal triggered")
    self.startExtendedRuntimeSession(trigger: .proactiveRenewal)
  }

  private func canStartRuntimeSession(for trigger: StartTrigger) -> Bool {
    if self.isAppActiveProvider() {
      return true
    }

    switch trigger {
    case .proactiveRenewal:
      return self.session?.state == .running
    case .begin, .invalidation:
      return false
    }
  }

  private func isCurrentSession(_ candidate: any ExtendedRuntimeSession) -> Bool {
    guard let session = self.session else { return false }
    return ObjectIdentifier(session) == ObjectIdentifier(candidate)
  }

  private func shouldRestartSession(
    reason: WKExtendedRuntimeSessionInvalidationReason,
    wasStarting: Bool
  ) -> Bool {
    if wasStarting && self.consecutiveStartFailures >= self.maxConsecutiveStartFailures {
      self.log("runtime restart budget exhausted after \(self.consecutiveStartFailures) startup failures")
      return false
    }

    switch reason {
    case .none:
      return false
    case .sessionInProgress:
      return true
    case .expired, .resignedFrontmost, .suppressedBySystem:
      return true
    case .error:
      return true
    @unknown default:
      return true
    }
  }

  private func shouldSuppressRestartInSimulator(
    reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) -> Bool {
    #if targetEnvironment(simulator)
    if reason == .error {
      let nsError = error as NSError?
      self.log(
        "simulator runtime invalidation suppressed: domain=\(nsError?.domain ?? "unknown"), code=\(nsError?.code ?? -1)")
      return true
    }
    #endif
    return false
  }

  private func log(_ message: String) {
    #if DEBUG
    print("[BackgroundRuntimeSessionController] \(message)")
    #endif
  }
}

extension BackgroundRuntimeSessionController: @MainActor BackgroundRuntimeManaging {}

// MARK: - WKExtendedRuntimeSessionDelegate

extension BackgroundRuntimeSessionController: ExtendedRuntimeSessionDelegate {
  func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: any ExtendedRuntimeSession) {
    guard self.isCurrentSession(extendedRuntimeSession) else { return }
    self.status = .running(startedAt: Date())
    self.lastError = nil
    self.lastInvalidationReason = nil
    self.consecutiveStartFailures = 0
    self.scheduleRenewalTimer()
    self.log("runtime session started")
  }

  func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: any ExtendedRuntimeSession) {
    guard self.isCurrentSession(extendedRuntimeSession) else { return }
    self.status = .expiring(Date())
    self.log("runtime session will expire soon -- triggering fallback renewal")
    self.performProactiveRenewal()
  }

  func extendedRuntimeSession(
    _ extendedRuntimeSession: any ExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    guard self.isCurrentSession(extendedRuntimeSession) else { return }
    let wasStarting: Bool
    if case .starting = self.status {
      wasStarting = true
    } else {
      wasStarting = false
    }
    self.status = .invalidated(reason: reason, error: error)
    self.lastError = error
    self.lastInvalidationReason = reason
    self.session = nil
    self.log("runtime session invalidated reason=\(reason.rawValue) wasStarting=\(wasStarting)")

    guard self.currentKind != nil else {
      self.status = .idle
      self.log("runtime invalidation ignored because no activity is active")
      return
    }

    if self.shouldSuppressRestartInSimulator(reason: reason, error: error) {
      return
    }

    guard self.canStartRuntimeSession(for: .invalidation(reason)) else {
      self.log("runtime restart deferred until app becomes active")
      return
    }

    if wasStarting {
      self.consecutiveStartFailures += 1
    } else {
      self.consecutiveStartFailures = 0
    }

    guard self.shouldRestartSession(reason: reason, wasStarting: wasStarting) else {
      return
    }
    self.startExtendedRuntimeSession(trigger: .invalidation(reason))
  }
}
#endif
