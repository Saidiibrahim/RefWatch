//
//  MatchActionsSheet.swift
//  RefWatchWatchOS
//
//  Description: Sheet presented when user long-presses on TimerView, showing match action options
//

import SwiftUI
import RefWatchCore

/// Sheet view presenting three action options for referees during a match
struct MatchActionsSheet: View {
    let matchViewModel: MatchViewModel
    var lifecycle: MatchLifecycleCoordinator? = nil
    @Environment(\.dismiss) private var dismiss
    
    // State for controlling navigation destinations
    @State private var showingMatchLogs = false
    @State private var showingOptions = false
    @State private var showingEndHalfConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Match Actions")
                .font(.headline)
                .padding(.top)
            
            // Action buttons in vertical layout for watch
            VStack(spacing: 16) {
                // Match Log Button
                ActionButton(
                    title: "Match Log",
                    icon: "list.bullet",
                    color: .blue
                ) {
                    showingMatchLogs = true
                }
                
                // Options Button
                ActionButton(
                    title: "Options",
                    icon: "ellipsis.circle",
                    color: .gray
                ) {
                    showingOptions = true
                }
                
                // End Half Button (conditional based on match state)
                if matchViewModel.isHalfTime {
                    // During half-time: Show "End Half" option with consistent styling
                    ActionButton(
                        title: "End Half",
                        icon: "checkmark.circle",
                        color: .green
                    ) {
                        matchViewModel.endHalfTimeManually()
                        dismiss()
                    }
                } else {
                    // During match: Show "End Half" option
                    ActionButton(
                        title: "End Half",
                        icon: "checkmark.circle",
                        color: .green
                    ) {
                        showingEndHalfConfirmation = true
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingMatchLogs) {
            MatchLogsView(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showingOptions) {
            MatchOptionsView(matchViewModel: matchViewModel, lifecycle: lifecycle)
        }
        .confirmationDialog(
            "",
            isPresented: $showingEndHalfConfirmation,
            titleVisibility: .hidden
        ) {
            Button("Yes") {
                let isFirstHalf = matchViewModel.currentPeriod == 1
                matchViewModel.endCurrentPeriod()
                if isFirstHalf {
                    matchViewModel.isHalfTime = true
                }
                dismiss()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text(
                (matchViewModel.currentMatch != nil && matchViewModel.currentPeriod == 2 && (matchViewModel.currentMatch?.numberOfPeriods ?? 2) == 2)
                ? "Are you sure you want to 'End Match'?"
                : "Are you sure you want to 'End Half'?"
            )
        }
    }
}


#Preview {
    MatchActionsSheet(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
