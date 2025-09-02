//
//  PenaltyFirstKickerView.swift
//  RefWatch Watch App
//
//  Description: Dedicated screen to select the first kicker before entering penalties.
//

import SwiftUI
import WatchKit

struct PenaltyFirstKickerView: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator

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
                firstKickerButton(title: matchViewModel.currentMatch?.homeTeam ?? "HOM", side: .home, color: .blue)
                firstKickerButton(title: matchViewModel.currentMatch?.awayTeam ?? "AWA", side: .away, color: .red)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .background(Color.black)
    }

    private func firstKickerButton(title: String, side: TeamSide, color: Color) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            matchViewModel.beginPenaltiesIfNeeded()
            matchViewModel.setPenaltyFirstKicker(side)
            lifecycle.goToPenalties()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(color))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(side == .home ? "firstKickerHomeBtn" : "firstKickerAwayBtn")
    }

    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(), lifecycle: MatchLifecycleCoordinator())
}

