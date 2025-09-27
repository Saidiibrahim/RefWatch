//
//  SupabaseIDTokenCredentials.swift
//  RefZoneiOS
//
//  Lightweight container for third-party identity tokens passed to Supabase.
//

import Foundation

struct SupabaseIDTokenCredentials: Equatable {
  enum Provider: String {
    case apple = "Apple"
    case google = "Google"
  }

  let provider: Provider
  let idToken: String
  let nonce: String?
}
