import Foundation

/// Separates Clerk's authentication subject from the app's internal database user ID.
struct AuthenticatedIdentity: Codable, Equatable, Sendable {
  let clerkUserId: String
  let appUserId: String
  let email: String?
  let displayName: String?
}

protocol AuthenticatedIdentityProviding {
  func authenticatedIdentity(
    forClerkUserId clerkUserId: String,
    forceRefresh: Bool) async throws -> AuthenticatedIdentity
  func invalidateCachedIdentity(forClerkUserId clerkUserId: String) async
}

extension AuthenticatedIdentityProviding {
  func authenticatedIdentity(forClerkUserId clerkUserId: String) async throws -> AuthenticatedIdentity {
    try await authenticatedIdentity(forClerkUserId: clerkUserId, forceRefresh: false)
  }

  func invalidateCachedIdentity(forClerkUserId _: String) async {}
}
