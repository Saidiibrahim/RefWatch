//
//  PenaltyFirstKickerView.swift
//  RefWatchWatchOS
//
//  Description: Dedicated screen to select the first kicker before entering penalties.
//

import SwiftUI
import WatchKit
import RefWatchCore

struct PenaltyFirstKickerView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var isRouting = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text(formattedCurrentTime)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Text("Who kicks first?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Buttons
            HStack(spacing: 12) {
                firstKickerButton(title: matchViewModel.homeTeamDisplayName, side: .home, color: .blue)
                firstKickerButton(title: matchViewModel.awayTeamDisplayName, side: .away, color: .red)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .background(Color.black)
    }

    private func firstKickerButton(title: String, side: TeamSide, color: Color) -> some View {
        Button(action: {
            // Haptic feedback and simple tap guard to avoid double navigation
            WKInterfaceDevice.current().play(.click)
            guard !isRouting else { return }
            isRouting = true

            // Coordinated penalty setup to prevent partial state corruption:
            // - startPenalties(withFirstKicker:) atomically begins the shootout and sets first kicker
            // - Only navigate if setup succeeds (returns true)
            // - On failure, we provide failure haptic feedback and keep the user on this screen
            // This replaces the previous multi-step beginPenaltiesIfNeeded() + setPenaltyFirstKicker() approach.
            let ok = matchViewModel.startPenalties(withFirstKicker: side)
            if ok {
                lifecycle.goToPenalties()
            } else {
                // If coordination failed (defensive), reset guard and notify via haptic
                isRouting = false
                WKInterfaceDevice.current().play(.failure)
            }
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(color))
        }
        .buttonStyle(.plain)
        .disabled(isRouting)
        .accessibilityIdentifier(side == .home ? "firstKickerHomeBtn" : "firstKickerAwayBtn")
    }

    private var formattedCurrentTime: String {
        DateFormatter.watchShortTime.string(from: Date())
    }
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
}
