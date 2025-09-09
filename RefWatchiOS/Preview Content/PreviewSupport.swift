//
//  PreviewSupport.swift
//  RefWatchiOS
//
//  Helpers for safe, realistic previews.
//

import SwiftUI
import RefWatchCore

#if DEBUG
extension AppRouter {
    static func preview(selected: AppRouter.Tab = .matches) -> AppRouter {
        let r = AppRouter()
        r.selectedTab = selected
        return r
    }
}

extension MatchViewModel {
    @MainActor
    static func previewActive() -> MatchViewModel {
        let vm = MatchViewModel(haptics: NoopHaptics())
        vm.newMatch = Match(homeTeam: "HOM", awayTeam: "AWA")
        vm.createMatch(); vm.startMatch()
        return vm
    }
}
#endif
