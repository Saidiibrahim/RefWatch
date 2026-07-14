import XCTest
import Combine
import RefWatchCore
@testable import RefWatchiOS

@MainActor
final class ClerkAuthControllerTests: XCTestCase {
  private var cancellables: Set<AnyCancellable> = []

  func testInit_whenClerkUserIdIsNotUUID_preservesSignedInIdentity() {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(
        id: "user_clerk-not-a-uuid",
        email: "ref@example.com",
        displayName: "Ref"))
    let controller = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)

    XCTAssertEqual(
      controller.state,
      .signedIn(
        userId: "user_clerk-not-a-uuid",
        email: "ref@example.com",
        displayName: "Ref"))
    XCTAssertEqual(controller.currentUserId, "user_clerk-not-a-uuid")
  }

  func testSessionToken_whenSignedIn_returnsAdapterToken() async throws {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_123", email: nil, displayName: nil),
      token: "session-token")
    let controller = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)

    let token = try await controller.sessionToken()
    XCTAssertEqual(token, "session-token")
  }

  func testSignOut_whenAdapterSucceeds_publishesSignedOut() async throws {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_123", email: nil, displayName: nil))
    let controller = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)

    try await controller.signOut()

    XCTAssertEqual(controller.state, .signedOut)
    XCTAssertNil(controller.currentUserId)
  }

  func testBackendAuthStateProvider_whenIdentityResolves_publishesInternalAppUserId() async {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_clerk-not-a-uuid", email: nil, displayName: nil))
    let clerkController = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)
    let identityProvider = IdentityProviderStub(
      identity: AuthenticatedIdentity(
        clerkUserId: "user_clerk-not-a-uuid",
        appUserId: "67d622c8-9976-4e8c-b47b-1883495e21a9",
        email: "ref@example.com",
        displayName: "Ref"))
    let provider = BackendAuthStateProvider(
      clerkStateProvider: clerkController,
      identityProvider: identityProvider)

    for _ in 0..<20 where provider.resolutionState != .ready {
      await Task.yield()
    }

    XCTAssertEqual(provider.currentUserId, "67d622c8-9976-4e8c-b47b-1883495e21a9")
    XCTAssertEqual(provider.identity?.clerkUserId, "user_clerk-not-a-uuid")
  }

  func testBackendAuthStateProvider_whenClerkSignsOut_invalidatesIdentityCache() async {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_a", email: nil, displayName: nil))
    let clerkController = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)
    let identityProvider = IdentityProviderSpy(
      identity: AuthenticatedIdentity(
        clerkUserId: "user_a",
        appUserId: "67d622c8-9976-4e8c-b47b-1883495e21a9",
        email: nil,
        displayName: nil))
    let provider = BackendAuthStateProvider(
      clerkStateProvider: clerkController,
      identityProvider: identityProvider)

    for _ in 0..<20 where provider.resolutionState != .ready {
      await Task.yield()
    }
    adapter.currentUser = nil
    await clerkController.restoreSessionIfAvailable()
    for _ in 0..<20 {
      if identityProvider.invalidationCount > 0 { break }
      await Task.yield()
    }

    XCTAssertEqual(provider.state, .signedOut)
    XCTAssertEqual(identityProvider.invalidationCount, 1)
  }

  func testBackendAuthStateProvider_whenAccountChanges_emitsCleanupBoundaryBeforeNewIdentity() async {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_a", email: nil, displayName: nil))
    let clerkController = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)
    let identityProvider = SwitchingIdentityProviderSpy(identities: [
      "user_a": AuthenticatedIdentity(
        clerkUserId: "user_a",
        appUserId: "67d622c8-9976-4e8c-b47b-1883495e21a9",
        email: "a@example.com",
        displayName: "Ref A"),
      "user_b": AuthenticatedIdentity(
        clerkUserId: "user_b",
        appUserId: "0b09fead-9d78-47ea-8cd9-2e4cd02533f7",
        email: "b@example.com",
        displayName: "Ref B"),
    ])
    let provider = BackendAuthStateProvider(
      clerkStateProvider: clerkController,
      identityProvider: identityProvider)
    var publishedStates: [AuthState] = []
    provider.statePublisher
      .sink { publishedStates.append($0) }
      .store(in: &cancellables)

    for _ in 0..<20 where provider.currentEmail != "a@example.com" {
      await Task.yield()
    }
    adapter.currentUser = ClerkUserSnapshot(id: "user_b", email: nil, displayName: nil)
    await clerkController.restoreSessionIfAvailable()
    for _ in 0..<20 where provider.currentEmail != "b@example.com" {
      await Task.yield()
    }
    for _ in 0..<20 where identityProvider.invalidatedClerkUserIds.isEmpty {
      await Task.yield()
    }

    XCTAssertEqual(publishedStates, [
      .signedIn(
        userId: "67d622c8-9976-4e8c-b47b-1883495e21a9",
        email: "a@example.com",
        displayName: "Ref A"),
      .signedOut,
      .signedIn(
        userId: "0b09fead-9d78-47ea-8cd9-2e4cd02533f7",
        email: "b@example.com",
        displayName: "Ref B"),
    ])
    XCTAssertEqual(identityProvider.invalidatedClerkUserIds, ["user_a"])
  }

  func testBackendAuthStateProvider_beforeSessionRestore_doesNotPublishSignedOut() async {
    let adapter = ClerkAuthAdapterStub(user: nil)
    let clerkController = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)
    let provider = BackendAuthStateProvider(
      clerkStateProvider: clerkController,
      identityProvider: FailingIdentityProvider())
    var publishedStates: [AuthState] = []
    provider.statePublisher
      .sink { publishedStates.append($0) }
      .store(in: &cancellables)

    await Task.yield()
    XCTAssertFalse(clerkController.isAuthStateResolved)
    XCTAssertTrue(publishedStates.isEmpty)

    await clerkController.restoreSessionIfAvailable()
    await Task.yield()
    XCTAssertEqual(publishedStates, [.signedOut])
  }

  func testBackendAuthStateProvider_whenIdentityResolutionFails_doesNotPublishSignedOut() async {
    let adapter = ClerkAuthAdapterStub(
      user: ClerkUserSnapshot(id: "user_a", email: nil, displayName: nil))
    let clerkController = ClerkAuthController(adapter: adapter, observeChangesOnInit: false)
    let provider = BackendAuthStateProvider(
      clerkStateProvider: clerkController,
      identityProvider: FailingIdentityProvider())
    var publishedStates: [AuthState] = []
    provider.statePublisher
      .sink { publishedStates.append($0) }
      .store(in: &cancellables)

    for _ in 0..<20 {
      if case .failed = provider.resolutionState { break }
      await Task.yield()
    }

    if case .failed = provider.resolutionState {} else {
      XCTFail("Expected identity resolution to fail")
    }
    XCTAssertTrue(publishedStates.isEmpty)
  }
}

@MainActor
private final class ClerkAuthAdapterStub: ClerkAuthAdapting {
  var currentUser: ClerkUserSnapshot?
  let token: String?

  init(user: ClerkUserSnapshot?, token: String? = "token") {
    currentUser = user
    self.token = token
  }

  var userChanges: AsyncStream<ClerkUserSnapshot?> {
    AsyncStream { continuation in
      continuation.yield(currentUser)
      continuation.finish()
    }
  }

  func sessionToken() async throws -> String? { token }

  func signOut() async throws {
    currentUser = nil
  }
}

private struct IdentityProviderStub: AuthenticatedIdentityProviding {
  let identity: AuthenticatedIdentity

  func authenticatedIdentity(
    forClerkUserId _: String,
    forceRefresh _: Bool) async throws -> AuthenticatedIdentity
  {
    identity
  }
}

private struct FailingIdentityProvider: AuthenticatedIdentityProviding {
  struct Failure: LocalizedError {
    var errorDescription: String? { "offline" }
  }

  func authenticatedIdentity(
    forClerkUserId _: String,
    forceRefresh _: Bool) async throws -> AuthenticatedIdentity
  {
    throw Failure()
  }
}

@MainActor
private final class IdentityProviderSpy: AuthenticatedIdentityProviding {
  let identity: AuthenticatedIdentity
  private(set) var invalidationCount = 0

  init(identity: AuthenticatedIdentity) {
    self.identity = identity
  }

  func authenticatedIdentity(
    forClerkUserId _: String,
    forceRefresh _: Bool) async throws -> AuthenticatedIdentity
  {
    identity
  }

  func invalidateCachedIdentity(forClerkUserId _: String) async {
    invalidationCount += 1
  }
}

@MainActor
private final class SwitchingIdentityProviderSpy: AuthenticatedIdentityProviding {
  let identities: [String: AuthenticatedIdentity]
  private(set) var invalidatedClerkUserIds: [String] = []

  init(identities: [String: AuthenticatedIdentity]) {
    self.identities = identities
  }

  func authenticatedIdentity(
    forClerkUserId clerkUserId: String,
    forceRefresh _: Bool) async throws -> AuthenticatedIdentity
  {
    guard let identity = identities[clerkUserId] else {
      throw FailingIdentityProvider.Failure()
    }
    return identity
  }

  func invalidateCachedIdentity(forClerkUserId clerkUserId: String) async {
    invalidatedClerkUserIds.append(clerkUserId)
  }
}
