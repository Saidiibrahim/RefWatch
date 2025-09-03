//
//  PreviewSupport.swift
//  RefWatchiOS
//
//  Helpers for safe, realistic previews.
//

import SwiftUI

#if DEBUG
extension AppRouter {
    static func preview(selected: AppRouter.Tab = .matches) -> AppRouter {
        let r = AppRouter()
        r.selectedTab = selected
        return r
    }
}

extension LiveSessionModel {
    static func preview(active: Bool = true) -> LiveSessionModel {
        let s = LiveSessionModel()
        if active {
            s.simulateStart(home: "HOM", away: "AWA")
        }
        return s
    }
}
#endif

