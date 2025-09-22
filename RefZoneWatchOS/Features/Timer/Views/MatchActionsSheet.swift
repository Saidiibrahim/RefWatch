//
//  MatchActionsSheet.swift
//  RefZoneWatchOS
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
    @Environment(\.theme) private var theme
    
    // State for controlling navigation destinations
    @State private var showingMatchLogs = false
    @State private var showingOptions = false
    @State private var showingEndHalfConfirmation = false
    
    var body: some View {
        // Two equal columns with compact spacing to fit on one screen
        let columns = Array(repeating: GridItem(.flexible(), spacing: theme.spacing.m), count: 2)
        let endActionTitle = matchViewModel.isFullTime ? "End Match" : "End Half"

        NavigationStack {
            GeometryReader { proxy in
                let hPadding = theme.components.cardHorizontalPadding
                let colSpacing = theme.spacing.m
                let cellWidth = (proxy.size.width - (hPadding * 2) - colSpacing) / 2

                ScrollView(.vertical) {
                    VStack(spacing: theme.spacing.l) {
                        // Top row: two primary actions
                        LazyVGrid(columns: columns, alignment: .center, spacing: theme.spacing.l) {
                            // Match Log
                            ActionGridItem(
                                title: "Match Log",
                                icon: "list.bullet",
                                color: theme.colors.accentSecondary,
                                showBackground: false // Remove background for Match Actions sheet
                            ) {
                                showingMatchLogs = true
                            }

                            // Options
                            ActionGridItem(
                                title: "Options",
                                icon: "ellipsis.circle",
                                color: theme.colors.accentMuted,
                                showBackground: false // Remove background for Match Actions sheet
                            ) {
                                showingOptions = true
                            }
                        }
                        
                        // Bottom row: single action centered to match column width
                        if matchViewModel.isHalfTime {
                            HStack {
                                Spacer(minLength: 0)
                                ActionGridItem(
                                    title: endActionTitle,
                                    icon: "checkmark.circle",
                                    color: theme.colors.matchPositive,
                                    expandHorizontally: false,
                                    showBackground: false // Remove background for Match Actions sheet
                                ) {
                                    matchViewModel.endHalfTimeManually()
                                    dismiss()
                                }
                                .frame(width: cellWidth)
                                Spacer(minLength: 0)
                            }
                        } else {
                            HStack {
                                Spacer(minLength: 0)
                                ActionGridItem(
                                    title: endActionTitle,
                                    icon: "checkmark.circle",
                                    color: theme.colors.matchPositive,
                                    expandHorizontally: false,
                                    showBackground: false // Remove background for Match Actions sheet
                                ) {
                                    showingEndHalfConfirmation = true
                                }
                                .frame(width: cellWidth)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, hPadding)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle("Match Actions")
            .background(theme.colors.backgroundPrimary)
        }
        .tint(theme.colors.accentSecondary)
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
                if matchViewModel.isFullTime {
                    matchViewModel.finalizeMatch()
                    DispatchQueue.main.async {
                        lifecycle?.resetToStart()
                        matchViewModel.resetMatch()
                    }
                    dismiss()
                    return
                }

                let isFirstHalf = matchViewModel.currentPeriod == 1
                matchViewModel.endCurrentPeriod()
                if isFirstHalf {
                    matchViewModel.isHalfTime = true
                }
                dismiss()
            }
            Button("No", role: .cancel) { }
        } message: {
            let prompt = matchViewModel.isFullTime
                ? "Are you sure you want to 'End Match'?"
                : ((matchViewModel.currentMatch != nil && matchViewModel.currentPeriod == 2 && (matchViewModel.currentMatch?.numberOfPeriods ?? 2) == 2)
                    ? "Are you sure you want to 'End Match'?"
                    : "Are you sure you want to 'End Half'?")
            Text(prompt)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    }
}


#Preview {
    MatchActionsSheet(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
