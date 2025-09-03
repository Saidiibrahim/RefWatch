//
//  AppRouter.swift
//  RefWatchiOS
//
//  Simple router to switch tabs from nested views
//

import SwiftUI
import Combine

final class AppRouter: ObservableObject {
    // 0: Matches, 1: Live, 2: Trends, 3: Library, 4: Settings
    @Published var selectedTab: Int = 0
}

