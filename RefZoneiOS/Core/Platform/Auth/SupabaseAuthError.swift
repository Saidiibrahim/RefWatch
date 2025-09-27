//
//  SupabaseAuthError.swift
//  RefZoneiOS
//
//  Typed errors surfaced by Supabase authentication flows so the UI can
//  present actionable feedback instead of raw SDK messages.
//

import Foundation

enum SupabaseAuthError: Error, LocalizedError, Equatable {
  case invalidEmail
  case invalidPassword
  case passwordTooShort
  case formIncomplete
  case emailAlreadyInUse
  case invalidCredentials
  case userNotFound
  case sessionExpired
  case thirdPartyCancelled
  case thirdPartyUnavailable(provider: String)
  case network
  case emailConfirmationRequired(email: String?)
  case unknown(message: String)

  var errorDescription: String? {
    switch self {
    case .invalidEmail:
      return "Enter a valid email address."
    case .invalidPassword:
      return "Password must not be empty."
    case .passwordTooShort:
      return "Password must be at least 8 characters."
    case .formIncomplete:
      return "Enter both an email and password to continue."
    case .emailAlreadyInUse:
      return "An account with this email already exists. Try signing in instead."
    case .invalidCredentials:
      return "The email or password you entered is incorrect."
    case .userNotFound:
      return "We couldn't find an account with this email."
    case .sessionExpired:
      return "Your session expired. Please sign in again."
    case .thirdPartyCancelled:
      return "Sign-in was cancelled."
    case let .thirdPartyUnavailable(provider):
      return "\(provider) sign-in is unavailable on this device."
    case let .emailConfirmationRequired(email):
      if let email, email.isEmpty == false {
        return "Check your inbox at \(email) to verify your account, then try signing in."
      }
      return "Check your email to verify your account, then try signing in."
    case .network:
      return "Check your internet connection and try again."
    case let .unknown(message):
      return message
    }
  }

  static func map(_ error: Error) -> SupabaseAuthError {
    if let authError = error as? SupabaseAuthError {
      return authError
    }

    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
      return .network
    }

    if let description = error.localizedDescription.nilIfPlaceholder {
      let lower = description.lowercased()
      if lower.contains("invalid login") || lower.contains("invalid email") {
        return .invalidCredentials
      }
      if lower.contains("user already registered") || lower.contains("already registered") || lower.contains("already exists") {
        return .emailAlreadyInUse
      }
      if lower.contains("not found") {
        return .userNotFound
      }
      if lower.contains("session expired") || lower.contains("expired refresh token") {
        return .sessionExpired
      }
      if lower.contains("accounts.google.com") && lower.contains("not enabled") {
        return .thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.google.rawValue)
      }
      if lower.contains("email not confirmed") || lower.contains("email confirmation required") {
        return .emailConfirmationRequired(email: nil)
      }
      if lower.contains("network") {
        return .network
      }
      return .unknown(message: description)
    }

    return .unknown(message: "Something went wrong. Please try again.")
  }
}

private extension String {
  var nilIfPlaceholder: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let defaultDescriptions: Set<String> = [
      "the operation couldn’t be completed.",
      "the operation couldn’t be completed (supabase.autherror error 1)."
    ]
    if defaultDescriptions.contains(trimmed.lowercased()) {
      return nil
    }
    return trimmed
  }
}
