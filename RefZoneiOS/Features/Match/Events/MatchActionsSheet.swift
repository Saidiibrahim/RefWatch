//
//  MatchActionsSheet.swift
//  RefZoneiOS
//
//  iOS actions hub for recording detailed match events.
//

import SwiftUI
import RefWatchCore

struct MatchActionsSheet: View {
    let matchViewModel: MatchViewModel

    @State private var showGoalFlow = false
    @State private var showCardFlow = false
    @State private var showSubFlow = false
    @State private var showEndPeriodConfirm = false
    @State private var showAdvanceConfirm = false
    @State private var showFullTime = false
    @State private var showResetConfirm = false
    @State private var showAbandonConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Events") {
                    Button {
                        showGoalFlow = true
                    } label: {
                        Label("Record Goal", systemImage: "soccerball")
                    }

                    Button {
                        showCardFlow = true
                    } label: {
                        Label("Record Card", systemImage: "rectangle.fill")
                    }

                    Button {
                        showSubFlow = true
                    } label: {
                        Label("Record Substitution", systemImage: "arrow.up.arrow.down")
                    }
                }

                Section("Period") {
                    if matchViewModel.isMatchInProgress {
                        Button {
                            matchViewModel.pauseMatch()
                        } label: { Label("Pause Timer", systemImage: "pause.circle") }
                    } else if !matchViewModel.isFullTime {
                        Button {
                            matchViewModel.resumeMatch()
                        } label: { Label("Resume Timer", systemImage: "play.circle") }
                    }

                    if matchViewModel.isMatchInProgress && !matchViewModel.isHalfTime {
                        Button {
                            showAdvanceConfirm = true
                        } label: { Label("Advance to Next Period", systemImage: "forward.fill") }
                    }

                    if matchViewModel.isMatchInProgress {
                        Button(role: .destructive) {
                            showEndPeriodConfirm = true
                        } label: { Label("End Current Period", systemImage: "stop.circle") }
                    }
                }

                Section("Finish") {
                    Button(role: .destructive) {
                        showFullTime = true
                    } label: { Label("Finish Match", systemImage: "flag.checkered") }
                }

                Section("Options") {
                    Button {
                        showResetConfirm = true
                    } label: { Label("Reset Match", systemImage: "arrow.counterclockwise") }

                    Button(role: .destructive) {
                        showAbandonConfirm = true
                    } label: { Label("Abandon Match", systemImage: "xmark.circle") }
                }
            }
            .navigationTitle("Match Actions")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGoalFlow) {
                GoalEventFlowView(matchViewModel: matchViewModel)
            }
            .sheet(isPresented: $showCardFlow) {
                CardEventFlowView(matchViewModel: matchViewModel)
            }
            .sheet(isPresented: $showSubFlow) {
                SubstitutionEventFlowView(matchViewModel: matchViewModel)
            }
            .sheet(isPresented: $showFullTime) {
                FullTimeView_iOS(matchViewModel: matchViewModel)
            }
            .confirmationDialog(
                "",
                isPresented: $showEndPeriodConfirm,
                titleVisibility: .hidden
            ) {
                Button("Yes") {
                    let isFinalReg = (matchViewModel.currentMatch != nil
                                      && matchViewModel.currentPeriod == (matchViewModel.currentMatch?.numberOfPeriods ?? 2)
                                      && (matchViewModel.currentMatch?.hasExtraTime == false))
                    matchViewModel.endCurrentPeriod()
                    if isFinalReg {
                        // When this ends the match in regulation, the timer will present Full Time
                    }
                }
                Button("No", role: .cancel) {}
            } message: {
                Text(
                    (matchViewModel.currentMatch != nil
                     && matchViewModel.currentPeriod == (matchViewModel.currentMatch?.numberOfPeriods ?? 2)
                     && (matchViewModel.currentMatch?.hasExtraTime == false))
                    ? "Are you sure you want to 'End Match'?"
                    : "Are you sure you want to 'End Half'?"
                )
            }
            .confirmationDialog(
                "",
                isPresented: $showAdvanceConfirm,
                titleVisibility: .hidden
            ) {
                Button("Yes") {
                    matchViewModel.startNextPeriod()
                }
                Button("No", role: .cancel) {}
            } message: {
                Text("Advance to next period now?")
            }
            .alert("Reset Match", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    matchViewModel.resetMatch()
                    dismiss()
                }
            } message: {
                Text("This will reset score, cards, and events. This cannot be undone.")
            }
            .alert("Abandon Match", isPresented: $showAbandonConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Abandon", role: .destructive) {
                    matchViewModel.abandonMatch()
                    dismiss()
                }
            } message: {
                Text("This will end the match immediately and record it as abandoned.")
            }
        }
    }
}
