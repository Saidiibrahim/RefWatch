//
//  SupabaseCredentialValidator.swift
//  RefZoneiOS
//
//  Shared helpers for validating email/password input before calling Supabase.
//

import Foundation

struct SupabaseCredentialValidator {
  static let minimumPasswordLength = 8

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

  func validate(email: String) throws {
    guard email.isEmpty == false else {
      throw SupabaseAuthError.formIncomplete
    }
    guard Self.isEmailValid(email) else {
      throw SupabaseAuthError.invalidEmail
    }
  }

  static func isEmailValid(_ email: String) -> Bool {
    let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
  }
}
