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
    @State private var showingConfirm = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(currentTime)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Full Time")
                        .font(.headline)
                }

                HStack(spacing: 16) {
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
                    Label("End Match", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.top, 16)
            .navigationTitle("Full Time")
            .navigationBarTitleDisplayMode(.inline)
            .alert("End Match", isPresented: $showingConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("End", role: .destructive) {
                    matchViewModel.finalizeMatch()
                    if let err = matchViewModel.lastPersistenceError, !err.isEmpty {
                        saveErrorMessage = err
                        showingSaveError = true
                    } else {
                        dismiss() // dismiss Full Time sheet; timer view handles popping
                    }
                }
            } message: {
                Text("This will finalize and save the match.")
            }
            .alert("Save Failed", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage.isEmpty ? "An unknown error occurred while saving." : saveErrorMessage)
            }
        }
    }

    private var currentTime: String {
        DateFormatter.watchShortTime.string(from: Date())
    }

    private func teamBox(name: String, score: Int) -> some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.headline)
            Text("\(score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
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

