import Combine
import Foundation
import RefWatchCore

/// Resolves the Clerk subject to the app's internal user ID before exposing auth to repositories.
@MainActor
final class BackendAuthStateProvider: ObservableObject, @preconcurrency AuthStateProviding {
  enum ResolutionState: Equatable {
    case idle
    case loading
    case ready
    case signedOut
    case failed(message: String)
  }

  @Published private(set) var state: AuthState = .signedOut
  @Published private(set) var identity: AuthenticatedIdentity?
  @Published private(set) var resolutionState: ResolutionState = .idle

  private let clerkStateProvider: any AuthStateProviding
  private let identityProvider: any AuthenticatedIdentityProviding
  private var clerkStateSubscription: AnyCancellable?
  private var identityTask: Task<Void, Never>?
  private var resolutionGeneration = UUID()
  private var lastClerkUserId: String?
  private var lastPublishedClerkUserId: String?

  init(
    clerkStateProvider: any AuthStateProviding,
    identityProvider: any AuthenticatedIdentityProviding)
  {
    self.clerkStateProvider = clerkStateProvider
    self.identityProvider = identityProvider
    clerkStateSubscription = Publishers.CombineLatest(
      clerkStateProvider.statePublisher,
      clerkStateProvider.authStateResolvedPublisher)
      .sink { [weak self] clerkState, isResolved in
        self?.handle(clerkState: clerkState, isResolved: isResolved, forceRefresh: false)
      }
  }

  deinit {
    identityTask?.cancel()
  }

  var currentUserId: String? {
    guard case let .signedIn(userId, _, _) = state else { return nil }
    return userId
  }

  var currentEmail: String? {
    guard case let .signedIn(_, email, _) = state else { return nil }
    return email
  }

  var currentDisplayName: String? {
    guard case let .signedIn(_, _, displayName) = state else { return nil }
    return displayName
  }

  var statePublisher: AnyPublisher<AuthState, Never> {
    Publishers.CombineLatest($state, $resolutionState)
      .compactMap { state, resolutionState -> AuthState? in
        switch resolutionState {
        case .ready:
          if case .signedIn = state { return state }
          return nil
        case .signedOut:
          return .signedOut
        case .idle, .loading, .failed:
          return nil
        }
      }
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  func retryIdentityResolution() {
    handle(
      clerkState: clerkStateProvider.state,
      isResolved: clerkStateProvider.isAuthStateResolved,
      forceRefresh: true)
  }

  private func handle(clerkState: AuthState, isResolved: Bool, forceRefresh: Bool) {
    identityTask?.cancel()
    resolutionGeneration = UUID()
    let generation = resolutionGeneration

    guard case let .signedIn(clerkUserId, _, _) = clerkState else {
      let clerkUserIdToInvalidate = identity?.clerkUserId ?? lastClerkUserId
      identity = nil
      lastPublishedClerkUserId = nil
      state = .signedOut
      resolutionState = isResolved ? .signedOut : .idle
      guard isResolved else { return }
      guard let clerkUserIdToInvalidate else { return }
      Task { [identityProvider] in
        await identityProvider.invalidateCachedIdentity(forClerkUserId: clerkUserIdToInvalidate)
      }
      return
    }

    if let previousClerkUserId = lastPublishedClerkUserId,
       previousClerkUserId != clerkUserId
    {
      // Repositories keep unscoped local caches. Emit a real sign-out boundary before
      // resolving the next account so every subscriber wipes the previous owner's data.
      identity = nil
      lastPublishedClerkUserId = nil
      state = .signedOut
      resolutionState = .signedOut
      Task { [identityProvider] in
        await identityProvider.invalidateCachedIdentity(forClerkUserId: previousClerkUserId)
      }
    }

    lastClerkUserId = clerkUserId

    if forceRefresh == false, let identity, identity.clerkUserId == clerkUserId {
      publish(identity)
      return
    }

    identity = nil
    state = .signedOut
    resolutionState = .loading
    identityTask = Task { [weak self, identityProvider] in
      do {
        let resolved = try await identityProvider.authenticatedIdentity(
          forClerkUserId: clerkUserId,
          forceRefresh: forceRefresh)
        guard Task.isCancelled == false,
              let self,
              self.resolutionGeneration == generation,
              self.clerkStateProvider.currentUserId == clerkUserId
        else { return }
        guard resolved.clerkUserId == clerkUserId else {
          throw BackendAPIError.unauthenticated(message: "Backend identity does not match the Clerk session.")
        }
        self.identity = resolved
        self.publish(resolved)
      } catch is CancellationError {
        return
      } catch {
        guard let self, self.resolutionGeneration == generation else { return }
        self.identity = nil
        self.state = .signedOut
        self.resolutionState = .failed(message: error.localizedDescription)
      }
    }
  }

  private func publish(_ identity: AuthenticatedIdentity) {
    lastPublishedClerkUserId = identity.clerkUserId
    state = .signedIn(
      userId: identity.appUserId,
      email: identity.email,
      displayName: identity.displayName)
    resolutionState = .ready
  }
}
