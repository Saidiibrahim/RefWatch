import Foundation

@MainActor
final class BackendIdentityProvider: AuthenticatedIdentityProviding {
  private let client: BackendAPIClient
  private let defaults: UserDefaults
  private let cacheKey: String
  private var cachedIdentity: AuthenticatedIdentity?

  init(
    client: BackendAPIClient,
    defaults: UserDefaults = .standard,
    cacheKey: String = "RefWatch.backendIdentity.v1")
  {
    self.client = client
    self.defaults = defaults
    self.cacheKey = cacheKey
    if let data = defaults.data(forKey: cacheKey),
       let identity = try? JSONDecoder().decode(AuthenticatedIdentity.self, from: data)
    {
      self.cachedIdentity = identity
    }
  }

  func authenticatedIdentity(
    forClerkUserId clerkUserId: String,
    forceRefresh: Bool) async throws -> AuthenticatedIdentity
  {
    let offlineFallback = forceRefresh == false && cachedIdentity?.clerkUserId == clerkUserId
      ? cachedIdentity
      : nil
    do {
      let identity: AuthenticatedIdentity = try await client.send(path: "/api/me")
      guard identity.clerkUserId == clerkUserId else {
        throw BackendAPIError.unauthenticated(
          message: "Backend identity does not match the Clerk session.")
      }
      cachedIdentity = identity
      if let data = try? JSONEncoder().encode(identity) {
        defaults.set(data, forKey: cacheKey)
      }
      return identity
    } catch let error as BackendAPIError {
      if case .transport = error, let offlineFallback {
        return offlineFallback
      }
      if case .localAuthenticationUnavailable = error, let offlineFallback {
        return offlineFallback
      }
      throw error
    }
  }

  func invalidateCachedIdentity(forClerkUserId clerkUserId: String) async {
    guard cachedIdentity?.clerkUserId == clerkUserId else { return }
    cachedIdentity = nil
    defaults.removeObject(forKey: cacheKey)
  }
}
