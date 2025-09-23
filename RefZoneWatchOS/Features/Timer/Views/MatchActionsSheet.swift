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
    @Environment(\.watchLayoutScale) private var layout
    
    // State for controlling navigation destinations
    @State private var showingMatchLogs = false
    @State private var showingOptions = false
    @State private var showingEndHalfConfirmation = false
    
    var body: some View {
        let endActionTitle = matchViewModel.isFullTime ? "End Match" : "End Half"

        NavigationStack {
            GeometryReader { proxy in
                let hPadding = theme.components.cardHorizontalPadding
                let colSpacing = theme.spacing.m
                let cellWidth = max(0, (proxy.size.width - (hPadding * 2) - colSpacing) / 2)

                ViewThatFits(in: .vertical) {
                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.l,
                        verticalSpacing: theme.spacing.l,
                        endActionTitle: endActionTitle
                    )

                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.m,
                        verticalSpacing: theme.spacing.m,
                        endActionTitle: endActionTitle
                    )

                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.s,
                        verticalSpacing: theme.spacing.s,
                        endActionTitle: endActionTitle
                    )
                }
                .padding(.horizontal, hPadding)
                .padding(.top, 2)
                .padding(.bottom, layout.safeAreaBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

private extension MatchActionsSheet {
    @ViewBuilder
    func actionContent(
        cellWidth: CGFloat,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        endActionTitle: String
    ) -> some View {
        VStack(spacing: verticalSpacing) {
            topRow(cellWidth: cellWidth, spacing: horizontalSpacing)
            bottomAction(cellWidth: cellWidth, title: endActionTitle)
            Spacer(minLength: 0)
        }
    }

    private func topRow(cellWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ActionGridItem(
                title: "Match Log",
                icon: "list.bullet",
                color: theme.colors.accentSecondary,
                showBackground: false
            ) {
                showingMatchLogs = true
            }
            .frame(width: cellWidth)

            ActionGridItem(
                title: "Options",
                icon: "ellipsis.circle",
                color: theme.colors.accentMuted,
                showBackground: false
            ) {
                showingOptions = true
            }
            .frame(width: cellWidth)
        }
    }

    @ViewBuilder
    private func bottomAction(cellWidth: CGFloat, title: String) -> some View {
        HStack {
            Spacer(minLength: 0)

            if matchViewModel.isHalfTime {
                ActionGridItem(
                    title: title,
                    icon: "checkmark.circle",
                    color: theme.colors.matchPositive,
                    expandHorizontally: false,
                    showBackground: false
                ) {
                    matchViewModel.endHalfTimeManually()
                    dismiss()
                }
                .frame(width: cellWidth)
            } else {
                ActionGridItem(
                    title: title,
                    icon: "checkmark.circle",
                    color: theme.colors.matchPositive,
                    expandHorizontally: false,
                    showBackground: false
                ) {
                    showingEndHalfConfirmation = true
                }
                .frame(width: cellWidth)
            }

            Spacer(minLength: 0)
        }
    }
}
