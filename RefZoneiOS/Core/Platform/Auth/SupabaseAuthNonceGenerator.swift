//
//  SupabaseAuthNonceGenerator.swift
//  RefZoneiOS
//
//  Utility helpers for generating cryptographic nonces required by
//  third-party sign-in providers.
//

import CryptoKit
import Foundation

struct SupabaseAuthNonceGenerator {
  static func randomNonce(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    precondition(status == errSecSuccess, "Unable to generate nonce. OSStatus \(status)")

    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { byte in
      charset[Int(byte) % charset.count]
    }
    return String(nonce)
  }

  static func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.map { String(format: "%02x", $0) }.joined()
  }
}
