//
//  ClerkAuth.swift
//  RefWatchiOS
//
//  Adapter that maps Clerk's user/session to the app's vendor-neutral
//  AuthenticationProviding protocol. Kept intentionally tiny and stateless;
//  consumers read `state`/`currentUserId` on demand at save/merge time.
//

import Foundation
import RefWatchCore

#if canImport(Clerk)
import Clerk
#endif

struct ClerkAuth: AuthenticationProviding {
    var state: AuthState {
        #if canImport(Clerk)
        if let user = Clerk.shared.user {
            let name = (user.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? (user.username?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                ?? user.id
            return .signedIn(userId: user.id, displayName: name)
        }
        #endif
        return .signedOut
    }

    var currentUserId: String? {
        #if canImport(Clerk)
        Clerk.shared.user?.id
        #else
        nil
        #endif
    }
}

