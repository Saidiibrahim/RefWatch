//
//  CompletedMatch+Ownership.swift
//  RefWatchCore
//
//  Helper for attaching owner identity to snapshots when available.
//

import Foundation

public extension CompletedMatch {
    /// Returns a copy of the snapshot with `ownerId` set from the provided auth
    /// if it is currently `nil` and a user is signed in. This operation is
    /// idempotent; calling it repeatedly will not change a snapshot that already
    /// contains an `ownerId`.
    func attachingOwnerIfMissing(using auth: AuthenticationProviding) -> CompletedMatch {
        guard ownerId == nil, let uid = auth.currentUserId else { return self }
        return CompletedMatch(
            id: id,
            completedAt: completedAt,
            match: match,
            events: events,
            schemaVersion: schemaVersion,
            ownerId: uid
        )
    }
}
