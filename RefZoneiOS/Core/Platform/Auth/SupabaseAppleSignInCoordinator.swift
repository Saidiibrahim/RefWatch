//
//  SupabaseAppleSignInCoordinator.swift
//  RefZoneiOS
//
//  Handles Sign in with Apple and produces Supabase-friendly credentials.
//

import AuthenticationServices
import Foundation

protocol SupabaseAppleSignInCoordinating {
  @MainActor
  func signIn() async throws -> SupabaseIDTokenCredentials
}

@MainActor
final class SupabaseAppleSignInCoordinator: NSObject, SupabaseAppleSignInCoordinating {
  private var continuation: CheckedContinuation<SupabaseIDTokenCredentials, Error>?
  private var currentNonce: String?

  func signIn() async throws -> SupabaseIDTokenCredentials {
    guard continuation == nil else {
      throw SupabaseAuthError.unknown(message: "Another sign-in request is already running.")
    }

    let nonce = SupabaseAuthNonceGenerator.randomNonce()
    currentNonce = nonce

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SupabaseIDTokenCredentials, Error>) in
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

extension SupabaseAppleSignInCoordinator: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    UIApplication.activeWindow ?? ASPresentationAnchor()
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      continuation?.resume(throwing: SupabaseAuthError.thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.apple.rawValue))
      continuation = nil
      return
    }

    guard let appleIDToken = credential.identityToken, let tokenString = String(data: appleIDToken, encoding: .utf8) else {
      continuation?.resume(throwing: SupabaseAuthError.unknown(message: "Unable to decode Apple identity token."))
      continuation = nil
      return
    }

    guard let nonce = currentNonce else {
      continuation?.resume(throwing: SupabaseAuthError.unknown(message: "Missing nonce for Apple sign-in."))
      continuation = nil
      return
    }

    let credentials = SupabaseIDTokenCredentials(provider: .apple, idToken: tokenString, nonce: nonce)
    continuation?.resume(returning: credentials)
    continuation = nil
    currentNonce = nil
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
      continuation?.resume(throwing: SupabaseAuthError.thirdPartyCancelled)
    } else {
      continuation?.resume(throwing: SupabaseAuthError.map(error))
    }
    continuation = nil
    currentNonce = nil
  }
}
