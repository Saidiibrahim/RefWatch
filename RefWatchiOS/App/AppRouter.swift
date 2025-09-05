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
        case matches, trends, library, settings
    }

    @Published var selectedTab: Tab = .matches
}
