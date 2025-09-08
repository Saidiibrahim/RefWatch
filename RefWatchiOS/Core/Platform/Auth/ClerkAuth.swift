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
    static func bestDisplayName(firstName: String?, username: String?, id: String) -> String {
        let trimmedFirst = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name = trimmedFirst, !name.isEmpty { return name }
        let trimmedUser = username?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uname = trimmedUser, !uname.isEmpty { return uname }
        return id
    }

    var state: AuthState {
        #if canImport(Clerk)
        if let user = Clerk.shared.user {
            let name = Self.bestDisplayName(firstName: user.firstName, username: user.username, id: user.id)
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
