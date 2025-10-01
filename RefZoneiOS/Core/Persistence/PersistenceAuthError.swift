//
//  PersistenceAuthError.swift
//  RefZoneiOS
//
//  Shared error surfaced when persistence layers are invoked while signed out.
//

import Foundation

enum PersistenceAuthError: LocalizedError {
    case signedOut(operation: String)

    var errorDescription: String? {
        switch self {
        case let .signedOut(operation):
            return "Sign in to \(operation)."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .signedOut:
            return "Authenticate with your Supabase account on iPhone to continue."
        }
    }
}
