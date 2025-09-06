//
//  MatchActionsSheet.swift
//  RefWatchiOS
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

                    if matchViewModel.isMatchInProgress {
                        Button(role: .destructive) {
                            matchViewModel.endCurrentPeriod()
                        } label: { Label("End Current Period", systemImage: "stop.circle") }
                    }
                }

                Section("Finish") {
                    Button(role: .destructive) {
                        matchViewModel.finalizeMatch()
                    } label: {
                        Label("Finish Match", systemImage: "flag.checkered")
                    }
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
        }
    }
}

