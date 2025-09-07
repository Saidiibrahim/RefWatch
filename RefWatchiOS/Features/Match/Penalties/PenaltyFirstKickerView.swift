//
//  PenaltyFirstKickerView.swift
//  RefWatchiOS
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
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Who kicks first?")
                        .font(.headline)
                }

                HStack(spacing: 12) {
                    firstKickerButton(title: matchViewModel.homeTeamDisplayName, side: .home)
                    firstKickerButton(title: matchViewModel.awayTeamDisplayName, side: .away)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Penalties")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Failed to start", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not start penalties. Try again.")
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
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(side == .home ? .blue : .red))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }
}

#Preview {
    PenaltyFirstKickerView(matchViewModel: MatchViewModel(haptics: NoopHaptics()))
}

