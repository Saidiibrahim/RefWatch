//
//  SupabaseAppleSignInCoordinator.swift
//  RefWatchiOS
//
//  Handles Sign in with Apple and produces Supabase-friendly credentials.
//

import AuthenticationServices
import Foundation

/// Abstraction for driving Sign in with Apple in a DocC-friendly way.
protocol SupabaseAppleSignInCoordinating {
  /// Initiates the Apple authorization flow and returns ID-token credentials on success.
  @MainActor
  func signIn() async throws -> SupabaseIDTokenCredentials
}

@MainActor
final class SupabaseAppleSignInCoordinator: NSObject, SupabaseAppleSignInCoordinating {
  /// Continuation used to bridge Apple's delegate callbacks back into async/await.
  private var continuation: CheckedContinuation<SupabaseIDTokenCredentials, Error>?
  private var currentNonce: String?

  /// Presents the Sign in with Apple sheet, returning credentials suitable for Supabase.
  func signIn() async throws -> SupabaseIDTokenCredentials {
    guard self.continuation == nil else {
      throw SupabaseAuthError.unknown(message: "Another sign-in request is already running.")
    }

    let nonce = SupabaseAuthNonceGenerator.randomNonce()
    self.currentNonce = nonce

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<
      SupabaseIDTokenCredentials,
      Error
    >) in
      self.continuation = continuation

      let request = ASAuthorizationAppleIDProvider().createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = SupabaseAuthNonceGenerator.sha256(nonce)

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.presentationContextProvider = self
      controller.performRequests()
    }
  }
}

extension SupabaseAppleSignInCoordinator: ASAuthorizationControllerDelegate,
ASAuthorizationControllerPresentationContextProviding {
  /// Resolves an anchor window for the system sheet.
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.activeWindow ?? ASPresentationAnchor()
  }

  /// Handles successful authorization by extracting an identity token and constructing credentials.
  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization)
  {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      self.continuation?
        .resume(
          throwing: SupabaseAuthError
            .thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.apple.rawValue))
      self.continuation = nil
      return
    }

    guard let appleIDToken = credential.identityToken,
          let tokenString = String(data: appleIDToken, encoding: .utf8)
    else {
      self.continuation?.resume(throwing: SupabaseAuthError.unknown(message: "Unable to decode Apple identity token."))
      self.continuation = nil
      return
    }

    guard let nonce = currentNonce else {
      self.continuation?.resume(throwing: SupabaseAuthError.unknown(message: "Missing nonce for Apple sign-in."))
      self.continuation = nil
      return
    }

    let credentials = SupabaseIDTokenCredentials(provider: .apple, idToken: tokenString, nonce: nonce)
    self.continuation?.resume(returning: credentials)
    self.continuation = nil
    self.currentNonce = nil
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
      self.continuation?.resume(throwing: SupabaseAuthError.thirdPartyCancelled)
    } else {
      self.continuation?.resume(throwing: SupabaseAuthError.map(error))
    }
    self.continuation = nil
    self.currentNonce = nil
  }
}
