//
//  PenaltyFirstKickerView.swift
//  RefZoneiOS
//
//  Choose first kicker and start penalties.
//

import SwiftUI
import RefWatchCore

struct PenaltyFirstKickerView: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var isSubmitting = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                VStack(spacing: theme.spacing.s - 2) {
                    Text("penalties_who_kicks_first")
                        .font(theme.typography.heroTitle)
                }

                HStack(spacing: 12) {
                    firstKickerButton(title: matchViewModel.homeTeamDisplayName, side: .home)
                    firstKickerButton(title: matchViewModel.awayTeamDisplayName, side: .away)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("penalties_title")
            .navigationBarTitleDisplayMode(.inline)
            .alert("penalties_start_failed_title", isPresented: $showError) {
                Button("common_ok", role: .cancel) {}
            } message: {
                Text("penalties_start_failed_message")
            }
        }
    }

    private func firstKickerButton(title: String, side: TeamSide) -> some View {
        Button {
            guard !isSubmitting else { return }
            isSubmitting = true
            let ok = matchViewModel.startPenalties(withFirstKicker: side)
            if ok {
                dismiss()
            } else {
                isSubmitting = false
                showError = true
            }
        } label: {
            Text(title)
                .font(theme.typography.heroTitle)
                .frame(maxWidth: .infinity)
                .frame(height: theme.components.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                        .fill(side == .home ? theme.colors.accentPrimary : theme.colors.matchCritical)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
