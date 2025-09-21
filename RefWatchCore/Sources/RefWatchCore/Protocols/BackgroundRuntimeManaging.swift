import Foundation

public enum BackgroundRuntimeActivityKind: String, Sendable, Equatable {
  case match
  case workout
}

public enum BackgroundRuntimeEndReason: Sendable, Equatable {
  case completed
  case cancelled
  case reset
  case failure
}

public protocol BackgroundRuntimeManaging: AnyObject, Sendable {
  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String])
  func notifyPause()
  func notifyResume()
  func end(reason: BackgroundRuntimeEndReason)
}

public final class NoopBackgroundRuntimeManager: BackgroundRuntimeManaging {
  public init() {}
  public func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {}
  public func notifyPause() {}
  public func notifyResume() {}
  public func end(reason: BackgroundRuntimeEndReason) {}
}
