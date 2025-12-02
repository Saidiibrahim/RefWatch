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

@MainActor
public protocol BackgroundRuntimeManaging: AnyObject {
  func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String])
  func notifyPause()
  func notifyResume()
  func end(reason: BackgroundRuntimeEndReason)
}

@MainActor
public final class NoopBackgroundRuntimeManager: BackgroundRuntimeManaging {
  public init() {}
  public func begin(kind: BackgroundRuntimeActivityKind, title: String?, metadata: [String: String]) {}
  public func notifyPause() {}
  public func notifyResume() {}
  public func end(reason: BackgroundRuntimeEndReason) {}
}
