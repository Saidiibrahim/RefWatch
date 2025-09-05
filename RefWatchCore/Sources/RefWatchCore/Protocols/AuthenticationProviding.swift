//
//  AuthenticationProviding.swift
//  RefWatchCore
//
//  Minimal, vendor-neutral authentication seam used by stores/sync.
//

import Foundation

public enum AuthState: Equatable {
    case signedOut
    case signedIn(userId: String, displayName: String)
}

public protocol AuthenticationProviding {
    var state: AuthState { get }
    var currentUserId: String? { get }
}

public struct NoopAuth: AuthenticationProviding {
    public init() {}
    public var state: AuthState { .signedOut }
    public var currentUserId: String? { nil }
}

