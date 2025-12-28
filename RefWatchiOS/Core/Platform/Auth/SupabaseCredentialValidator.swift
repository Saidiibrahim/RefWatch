//
//  SupabaseCredentialValidator.swift
//  RefWatchiOS
//
//  Shared helpers for validating email/password input before calling Supabase.
//

import Foundation

/// Lightweight helpers for validating credentials before they reach Supabase.
///
/// Use ``SupabaseCredentialValidator`` to provide fast, user-friendly feedback in the
/// Settings authentication form and to guard network calls with predictable requirements.
struct SupabaseCredentialValidator {
  /// The minimum password length enforced locally before delegating to Supabase.
  static let minimumPasswordLength = 8

  /// Validates an email/password pair according to local heuristics.
  ///
  /// - Parameters:
  ///   - email: The user-supplied email.
  ///   - password: The user-supplied password.
  /// - Throws: ``SupabaseAuthError`` when a field is empty, malformed, or too short.
  func validate(email: String, password: String) throws {
    guard email.isEmpty == false, password.isEmpty == false else {
      throw SupabaseAuthError.formIncomplete
    }
    guard Self.isEmailValid(email) else {
      throw SupabaseAuthError.invalidEmail
    }
    guard password.count >= Self.minimumPasswordLength else {
      throw SupabaseAuthError.passwordTooShort
    }
  }

  /// Validates an email for flows that only require address input (for example password reset).
  ///
  /// - Parameter email: The user-supplied email address.
  /// - Throws: ``SupabaseAuthError`` when the address is empty or malformed.
  func validate(email: String) throws {
    guard email.isEmpty == false else {
      throw SupabaseAuthError.formIncomplete
    }
    guard Self.isEmailValid(email) else {
      throw SupabaseAuthError.invalidEmail
    }
  }

  /// Tests whether a string conforms to a basic email format pattern.
  static func isEmailValid(_ email: String) -> Bool {
    let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
  }
}
