import Combine
import Foundation
import RefWatchCore

#if canImport(ClerkKit)
import ClerkKit
#endif

@MainActor
private final class ClerkPreviewAuthAdapter: ClerkAuthAdapting {
  let currentUser: ClerkUserSnapshot?
  var userChanges: AsyncStream<ClerkUserSnapshot?> {
    AsyncStream { continuation in
      continuation.yield(currentUser)
      continuation.finish()
    }
  }

  init(user: ClerkUserSnapshot?) { currentUser = user }
  func sessionToken() async throws -> String? { "preview-clerk-session-token" }
  func signOut() async throws {}
}

extension ClerkAuthController {
  static func previewSignedIn(
    userId: String = "user_preview_referee",
    email: String = "referee@example.com",
    displayName: String = "Preview Referee") -> ClerkAuthController
  {
    ClerkAuthController(
      adapter: ClerkPreviewAuthAdapter(
        user: ClerkUserSnapshot(id: userId, email: email, displayName: displayName)),
      observeChangesOnInit: false)
  }

  static func previewSignedOut() -> ClerkAuthController {
    ClerkAuthController(adapter: ClerkPreviewAuthAdapter(user: nil), observeChangesOnInit: false)
  }
}

struct ClerkUserSnapshot: Equatable, Sendable {
  let id: String
  let email: String?
  let displayName: String?
}

@MainActor
protocol ClerkAuthAdapting: AnyObject {
  var currentUser: ClerkUserSnapshot? { get }
  var userChanges: AsyncStream<ClerkUserSnapshot?> { get }
  func sessionToken() async throws -> String?
  func signOut() async throws
}

@MainActor
final class ClerkAuthController: ObservableObject, @preconcurrency AuthStateProviding, SessionTokenProviding {
  @Published private(set) var state: AuthState = .signedOut
  @Published private(set) var lastError: ClerkAuthError?
  @Published private(set) var isAuthStateResolved = false

  private let adapter: any ClerkAuthAdapting
  private var observationTask: Task<Void, Never>?

  init(adapter: any ClerkAuthAdapting, observeChangesOnInit: Bool = true) {
    self.adapter = adapter
    refreshState(from: adapter.currentUser, confirmsSignedOut: false)
    if observeChangesOnInit {
      observeChanges()
    }
  }

  #if canImport(ClerkKit)
  convenience init(observeChangesOnInit: Bool = true) {
    self.init(adapter: ClerkSDKAuthAdapter(), observeChangesOnInit: observeChangesOnInit)
  }
  #endif

  deinit {
    observationTask?.cancel()
  }

  var currentUserId: String? {
    guard case let .signedIn(userId, _, _) = state else { return nil }
    return userId
  }

  var isSignedIn: Bool { currentUserId != nil }

  var currentEmail: String? {
    guard case let .signedIn(_, email, _) = state else { return nil }
    return email
  }

  var currentDisplayName: String? {
    guard case let .signedIn(_, _, displayName) = state else { return nil }
    return displayName
  }

  var statePublisher: AnyPublisher<AuthState, Never> {
    $state.removeDuplicates().eraseToAnyPublisher()
  }

  var authStateResolvedPublisher: AnyPublisher<Bool, Never> {
    $isAuthStateResolved.removeDuplicates().eraseToAnyPublisher()
  }

  func restoreSessionIfAvailable() async {
    refreshState(from: adapter.currentUser, confirmsSignedOut: true)
  }

  func signOut() async throws {
    do {
      try await adapter.signOut()
      refreshState(from: nil, confirmsSignedOut: true)
      lastError = nil
    } catch {
      let mapped = ClerkAuthError.map(error)
      lastError = mapped
      throw mapped
    }
  }

  func sessionToken() async throws -> String {
    guard currentUserId != nil else { throw ClerkAuthError.signedOut }
    do {
      guard let token = try await adapter.sessionToken(), token.isEmpty == false else {
        throw ClerkAuthError.tokenUnavailable
      }
      return token
    } catch {
      let mapped = ClerkAuthError.map(error)
      lastError = mapped
      throw mapped
    }
  }

  func clearLastError() {
    lastError = nil
  }

  private func observeChanges() {
    observationTask?.cancel()
    observationTask = Task { [weak self, adapter] in
      for await user in adapter.userChanges {
        guard Task.isCancelled == false else { return }
        self?.refreshState(from: user, confirmsSignedOut: self?.isAuthStateResolved == true)
      }
    }
  }

  private func refreshState(from user: ClerkUserSnapshot?, confirmsSignedOut: Bool) {
    guard let user else {
      guard confirmsSignedOut else { return }
      state = .signedOut
      isAuthStateResolved = true
      return
    }
    state = .signedIn(userId: user.id, email: user.email, displayName: user.displayName)
    isAuthStateResolved = true
  }
}

#if canImport(ClerkKit)
@MainActor
private final class ClerkSDKAuthAdapter: ClerkAuthAdapting {
  private let clerk: Clerk

  init(clerk: Clerk? = nil) {
    self.clerk = clerk ?? Clerk.shared
  }

  var currentUser: ClerkUserSnapshot? {
    Self.snapshot(clerk.user)
  }

  var userChanges: AsyncStream<ClerkUserSnapshot?> {
    AsyncStream { continuation in
      continuation.yield(Self.snapshot(self.clerk.user))
      let task = Task { @MainActor [clerk] in
        for await event in clerk.auth.events {
          guard Task.isCancelled == false else { return }
          switch event {
          case .signInCompleted(_),
               .signInNeedsContinuation(_),
               .signUpCompleted(_),
               .signUpNeedsContinuation(_),
               .signedOut(_),
               .accountDeleted,
               .sessionChanged(_, _):
            continuation.yield(Self.snapshot(clerk.user))
          case .tokenRefreshed(_):
            break
          }
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  func sessionToken() async throws -> String? {
    try await clerk.auth.getToken()
  }

  func signOut() async throws {
    try await clerk.auth.signOut()
  }

  private static func snapshot(_ user: User?) -> ClerkUserSnapshot? {
    guard let user else { return nil }
    let fullName = [user.firstName, user.lastName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
      .joined(separator: " ")
    return ClerkUserSnapshot(
      id: user.id,
      email: user.primaryEmailAddress?.emailAddress,
      displayName: fullName.isEmpty ? user.username : fullName)
  }
}
#endif
