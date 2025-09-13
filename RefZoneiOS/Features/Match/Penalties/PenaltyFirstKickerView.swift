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
    @State private var isSubmitting = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.l) {
                VStack(spacing: AppTheme.Spacing.s - 2) {
                    Text("penalties_who_kicks_first")
                        .font(AppTheme.Typography.header)
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
                .font(AppTheme.Typography.header)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.Buttons.heightM)
                .background(RoundedRectangle(cornerRadius: AppTheme.Corners.m).fill(side == .home ? .blue : .red))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}
