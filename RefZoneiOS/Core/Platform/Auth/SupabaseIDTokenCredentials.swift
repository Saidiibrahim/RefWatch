//
//  SupabaseIDTokenCredentials.swift
//  RefZoneiOS
//
//  Lightweight container for third-party identity tokens passed to Supabase.
//

import Foundation

/// A simple value type that packages identity tokens returned by platform SDKs for Supabase.
struct SupabaseIDTokenCredentials: Equatable {
  /// Names the upstream identity provider responsible for issuing the token.
  enum Provider: String {
    case apple = "Apple"
    case google = "Google"
  }

  /// The raw JWT returned by the identity provider.
  let provider: Provider
  /// The nonce used to bind the request (plain text for Google, unhashed for Apple).
  let idToken: String
  /// Optional nonce that Supabase uses to verify the token exchange.
  let nonce: String?
}
