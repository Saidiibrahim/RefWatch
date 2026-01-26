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
        case matches, trends, assistant, settings
    }

    @Published var selectedTab: Tab = .matches
    @Published var authenticationRequest: AuthenticationCoordinator.Screen?

    func coerceToValidTab(_ tab: Tab?) {
        guard let tab else { return }
        selectedTab = tab
    }

    /// Presents the authentication flow and optionally specifies the starting screen.
    func presentAuthentication(_ screen: AuthenticationCoordinator.Screen = .signIn) {
        authenticationRequest = screen
    }
}
