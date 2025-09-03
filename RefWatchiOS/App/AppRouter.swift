//
//  AppRouter.swift
//  RefWatchiOS
//
//  Simple router to switch tabs from nested views
//

import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    enum Tab: Int, CaseIterable, Hashable {
        case matches, live, trends, library, settings
    }

    @Published var selectedTab: Tab = .matches

    // Centralized navigation helpers to avoid scattering tab logic in views
    func openLive(home: String, away: String, session: LiveSessionModel) {
        session.simulateStart(home: home, away: away)
        selectedTab = .live
    }
}
