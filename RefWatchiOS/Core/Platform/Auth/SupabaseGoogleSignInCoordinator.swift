//
//  SupabaseGoogleSignInCoordinator.swift
//  RefWatchiOS
//
//  Bridges Google Sign-In SDK to Supabase auth token requirements.
//

import Foundation
import UIKit

/// Abstraction for driving Google Identity Services and returning Supabase-friendly tokens.
protocol SupabaseGoogleSignInCoordinating {
  /// Initiates Google Sign-In and returns ID-token credentials that can be exchanged with Supabase.
  @MainActor
  func signIn() async throws -> SupabaseIDTokenCredentials
}

#if canImport(GoogleSignIn)
import GoogleSignIn

@MainActor
final class SupabaseGoogleSignInCoordinator: SupabaseGoogleSignInCoordinating {
  /// Presents Google Sign-In, normalizes the nonce requirements, and wraps the provider's token.
  func signIn() async throws -> SupabaseIDTokenCredentials {
    guard let presenter = UIApplication.topViewController() else {
      throw SupabaseAuthError.thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.google.rawValue)
    }

    let rawNonce = SupabaseAuthNonceGenerator.randomNonce()

    // Configure Google Sign-In with proper client ID from GoogleService-Info.plist or fallback to Info.plist
    if GIDSignIn.sharedInstance.configuration == nil {
      var clientID: String?

      // Try to get client ID from GoogleService-Info.plist first
      if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let plist = NSDictionary(contentsOfFile: path),
         let plistClientID = plist["CLIENT_ID"] as? String
      {
        clientID = plistClientID
      } else {
        // Fallback to Info.plist configuration
        clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
      }

      guard let validClientID = clientID, !validClientID.isEmpty else {
        throw SupabaseAuthError.thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.google.rawValue)
      }

      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: validClientID)
    }

    return try await withCheckedThrowingContinuation { continuation in
      GIDSignIn.sharedInstance.signIn(
        withPresenting: presenter,
        hint: nil,
        additionalScopes: ["email"])
      { result, error in
        if let error {
          if (error as NSError).code == -2 { // GIDSignInErrorCode.canceled.rawValue
            continuation.resume(throwing: SupabaseAuthError.thirdPartyCancelled)
          } else {
            continuation.resume(throwing: SupabaseAuthError.map(error))
          }
          return
        }

        guard let user = result?.user, let idToken = user.idToken?.tokenString else {
          continuation.resume(
            throwing: SupabaseAuthError.unknown(
              message: "Google sign-in did not return a valid token."))
          return
        }

        // Use the raw nonce (not hashed) for Supabase as Supabase handles the hashing internally
        let credentials = SupabaseIDTokenCredentials(provider: .google, idToken: idToken, nonce: rawNonce)
        continuation.resume(returning: credentials)
      }
    }
  }
}
#else

@MainActor
final class SupabaseGoogleSignInCoordinator: SupabaseGoogleSignInCoordinating {
  /// Throws ``SupabaseAuthError/thirdPartyUnavailable(provider:)`` when the Google SDK is unavailable.
  func signIn() async throws -> SupabaseIDTokenCredentials {
    throw SupabaseAuthError.thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.google.rawValue)
  }
}

#endif
