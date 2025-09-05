//
//  MatchesTabView.swift
//  RefWatchiOS
//
//  Hub for iOS match flow: start a match and browse history.
//

import SwiftUI
import RefWatchCore

struct MatchesTabView: View {
    @EnvironmentObject private var router: AppRouter
    let matchViewModel: MatchViewModel
    @State private var path: [Route] = []
    enum Route: Hashable { case setup, timer, historyList }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.setup) {
                        Label("Start Match", systemImage: "play.circle.fill")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Matches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.historyList) } label: { Label("History", systemImage: "clock") }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup:
                    MatchSetupView(matchViewModel: matchViewModel) { _ in
                        path.append(.timer)
                    }
                case .timer:
                    MatchTimerView(matchViewModel: matchViewModel)
                case .historyList:
                    MatchHistoryView(matchViewModel: matchViewModel)
                }
            }
        }
    }
}
#Preview {
    MatchesTabView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
        .environmentObject(AppRouter.preview())
}
 
// No additional helpers.
