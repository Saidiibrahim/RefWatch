//
//  AuthStateDebugger.swift
//  RefZoneiOS
//
//  DEBUG-only helper to log authentication state transitions without
//  introducing vendor coupling. Called from App after Clerk loads and
//  whenever the user id changes.
//

import Foundation

#if DEBUG
final class AuthStateDebugger {
    static let shared = AuthStateDebugger()
    private var lastUserId: String?

    private init() {}

    func logChange(userId: String?, displayName: String?) {
        guard userId != lastUserId else { return }
        if let id = userId {
            let name = (displayName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? id
            print("DEBUG: Auth state → signed-in (uid=\(id), name=\(name))")
        } else {
            print("DEBUG: Auth state → signed-out")
        }
        lastUserId = userId
    }
}
#endif
