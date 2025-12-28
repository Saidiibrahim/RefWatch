//
//  FullTimeView_iOS.swift
//  RefWatchiOS
//
//  iOS Full Time view: shows final scores and requires explicit
//  confirmation before finalizing/saving the match snapshot.
//

import SwiftUI
import RefWatchCore

struct FullTimeView_iOS: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showingConfirm = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.xl) {
                VStack(spacing: theme.spacing.s - 2) {
                    Text(currentTime)
                        .font(theme.typography.heroSubtitle)
                        .foregroundStyle(.secondary)
                    Text("full_time_title")
                        .font(theme.typography.heroTitle)
                }

                HStack(spacing: theme.spacing.l) {
                    teamBox(name: matchViewModel.homeTeamDisplayName,
                            score: matchViewModel.currentMatch?.homeScore ?? 0)
                    teamBox(name: matchViewModel.awayTeamDisplayName,
                            score: matchViewModel.currentMatch?.awayScore ?? 0)
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    showingConfirm = true
                } label: {
                    Label(LocalizedStringKey("end_match_cta"), systemImage: "checkmark.circle.fill")
                        .font(theme.typography.heroTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.top, theme.spacing.l)
            .navigationTitle("full_time_title")
            .navigationBarTitleDisplayMode(.inline)
            .alert("end_match_alert_title", isPresented: $showingConfirm) {
                Button("common_cancel", role: .cancel) {}
                Button("common_end", role: .destructive) {
                    matchViewModel.finalizeMatch()
                    if let err = matchViewModel.lastPersistenceError, !err.isEmpty {
                        saveErrorMessage = err
                        showingSaveError = true
                    } else {
                        dismiss() // dismiss Full Time sheet; timer view handles popping
                    }
                }
            } message: {
                Text("end_match_alert_message")
            }
            .alert("save_failed_alert_title", isPresented: $showingSaveError) {
                Button("common_ok", role: .cancel) {}
            } message: {
                Text(saveErrorMessage.isEmpty ? String(localized: "save_failed_alert_fallback") : saveErrorMessage)
            }
        }
    }

    private var currentTime: String {
        DateFormatter.watchShortTime.string(from: Date())
    }

    private func teamBox(name: String, score: Int) -> some View {
        VStack(spacing: theme.spacing.s) {
            Text(name)
                .font(theme.typography.heroSubtitle)
            Text("\(score)")
                .font(theme.typography.timerPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                .fill(theme.colors.backgroundElevated)
        )
    }
}

#Preview {
    let vm = MatchViewModel(haptics: NoopHaptics())
    vm.newMatch = Match(homeTeam: "Home", awayTeam: "Away")
    vm.createMatch()
    vm.updateScore(isHome: true)
    vm.updateScore(isHome: false)
    vm.isFullTime = true
    return FullTimeView_iOS(matchViewModel: vm)
}
