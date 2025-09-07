//
//  SyncDiagnosticsCenter.swift
//  RefWatchiOS
//
//  Observes sync diagnostics notifications and exposes user-facing state.
//

import Foundation
import Combine
import RefWatchCore

final class SyncDiagnosticsCenter: ObservableObject {
    @Published var lastErrorMessage: String? = nil
    @Published var lastErrorContext: String? = nil
    @Published var showBanner: Bool = false

    private var observerTokens: [NSObjectProtocol] = []

    init(center: NotificationCenter = .default) {
        let nonrecoverable = center.addObserver(forName: .syncNonrecoverableError, object: nil, queue: .main) { [weak self] note in
            let msg = note.userInfo?["error"] as? String ?? "Sync error"
            let ctx = note.userInfo?["context"] as? String
            self?.lastErrorMessage = msg
            self?.lastErrorContext = ctx
            self?.showBanner = true
        }
        observerTokens.append(nonrecoverable)
    }

    deinit {
        for t in observerTokens { NotificationCenter.default.removeObserver(t) }
        observerTokens.removeAll()
    }

    func dismiss() { showBanner = false }
}
