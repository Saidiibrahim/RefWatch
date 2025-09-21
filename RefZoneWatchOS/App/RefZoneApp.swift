//
//  RefWatchApp.swift
//  RefZoneWatchOS
//
//  Created by Ibrahim Saidi on 11/1/2025.
//

import SwiftUI
import RefWatchCore
import RefWorkoutCore

@main
struct RefZone_Watch_AppApp: App {
    @StateObject private var appModeController = AppModeController()
    private let workoutServices = WorkoutServicesFactory.makeDefault()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appModeController)
                .workoutServices(workoutServices)
        }
    }
}
