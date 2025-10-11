//
//  AuthenticationProviding.swift
//  RefWatchCore
//
//  Minimal, vendor-neutral authentication seam used by stores/sync.
//

import Foundation

public enum AuthState: Equatable {
    case signedOut
    case signedIn(userId: String, email: String?, displayName: String?)
}

public protocol AuthenticationProviding {
    var state: AuthState { get }
    /// Active Supabase user identifier when signed in.
    var currentUserId: String? { get }
    /// Convenience accessor for current email address if available.
    var currentEmail: String? { get }
    /// Human-friendly name when the user is signed in.
    var currentDisplayName: String? { get }
}

public struct NoopAuth: AuthenticationProviding {
    public init() {}
    public var state: AuthState { .signedOut }
    public var currentUserId: String? { nil }
    public var currentEmail: String? { nil }
    public var currentDisplayName: String? { nil }
}
