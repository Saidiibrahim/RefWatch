//
//  MatchActionsSheet.swift
//  RefZoneWatchOS
//
//  Description: Sheet presented when user long-presses on TimerView, showing match action options
//

import SwiftUI
import WatchKit
import RefWatchCore

/// Sheet view presenting four action options for referees during a match
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
        // Determine end action title based on state
        let endActionTitle = computeEndActionTitle()

        NavigationStack {
            GeometryReader { proxy in
                let hPadding = theme.components.cardHorizontalPadding
                let colSpacing = theme.spacing.m
                let cellWidth = max(0, (proxy.size.width - (hPadding * 2) - colSpacing) / 2)

                ViewThatFits(in: .vertical) {
                    // Standard spacing - for larger watches (45mm+)
                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.l,
                        verticalSpacing: theme.spacing.l,
                        endActionTitle: endActionTitle
                    )

                    // Medium spacing
                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.m,
                        verticalSpacing: theme.spacing.m,
                        endActionTitle: endActionTitle
                    )

                    // Small spacing
                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.s,
                        verticalSpacing: theme.spacing.s,
                        endActionTitle: endActionTitle
                    )

                    // Extra small spacing for 42mm watches
                    actionContent(
                        cellWidth: cellWidth,
                        horizontalSpacing: theme.spacing.xs,
                        verticalSpacing: theme.spacing.xs,
                        endActionTitle: endActionTitle
                    )

                    // Ultra-compact for very small screens
                    ultraCompactContent(
                        cellWidth: cellWidth,
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
            // Top row remains: Match Log + Options. We keep spacing adaptive via ViewThatFits.
            topRow(cellWidth: cellWidth, spacing: horizontalSpacing)
            // Bottom row now has two cells: Undo + End Half/Match.
            bottomRow(cellWidth: cellWidth, spacing: horizontalSpacing, endActionTitle: endActionTitle)
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

    // New bottom row for the 2x2 grid. Adds Undo placeholder and keeps End action logic.
    @ViewBuilder
    private func bottomRow(cellWidth: CGFloat, spacing: CGFloat, endActionTitle: String) -> some View {
        HStack(spacing: spacing) {
            // Undo placeholder — prints a debug message for now
            ActionGridItem(
                title: "Undo",
                icon: "arrow.uturn.backward.circle",
                color: theme.colors.accentMuted,
                showBackground: false
            ) {
                if matchViewModel.undoLastUserEvent() {
                    dismiss()
                } else {
                    WKInterfaceDevice.current().play(.failure)
                    print("[MatchActionsSheet] Undo tapped but no undoable event found")
                }
            }
            .frame(width: cellWidth)

            // End Half/Match action follows existing behavior
            if matchViewModel.isHalfTime {
                ActionGridItem(
                    title: endActionTitle,
                    icon: "arrow.right.circle",
                    color: theme.colors.matchPositive,
                    showBackground: false
                ) {
                    matchViewModel.endHalfTimeManually()
                    dismiss()
                }
                .frame(width: cellWidth)
            } else {
                ActionGridItem(
                    title: endActionTitle,
                    icon: "checkmark.circle",
                    color: theme.colors.matchPositive,
                    showBackground: false
                ) {
                    // Check if we should skip confirmation (final period and time expired)
                    if shouldSkipConfirmation {
                        executeEndActionDirectly()
                    } else {
                        showingEndHalfConfirmation = true
                    }
                }
                .frame(width: cellWidth)
            }
        }
    }

    // Ultra-compact layout for very small watches (42mm and smaller)
    @ViewBuilder
    private func ultraCompactContent(cellWidth: CGFloat, endActionTitle: String) -> some View {
        VStack(spacing: theme.spacing.xs) {
            // Top row with minimal spacing
            HStack(spacing: theme.spacing.xs) {
                compactActionItem(
                    title: "Match Log",
                    icon: "list.bullet",
                    color: theme.colors.accentSecondary,
                    width: cellWidth
                ) {
                    showingMatchLogs = true
                }

                compactActionItem(
                    title: "Options",
                    icon: "ellipsis.circle",
                    color: theme.colors.accentMuted,
                    width: cellWidth
                ) {
                    showingOptions = true
                }
            }

            // Bottom row with minimal spacing
            HStack(spacing: theme.spacing.xs) {
                compactActionItem(
                    title: "Undo",
                    icon: "arrow.uturn.backward.circle",
                    color: theme.colors.accentMuted,
                    width: cellWidth
                ) {
                    if matchViewModel.undoLastUserEvent() {
                        dismiss()
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                        print("[MatchActionsSheet] Undo tapped but no undoable event found")
                    }
                }

                // End Half/Match action follows existing behavior
                if matchViewModel.isHalfTime {
                    compactActionItem(
                        title: endActionTitle,
                        icon: "arrow.right.circle",
                        color: theme.colors.matchPositive,
                        width: cellWidth
                    ) {
                        matchViewModel.endHalfTimeManually()
                        dismiss()
                    }
                } else {
                    compactActionItem(
                        title: endActionTitle,
                        icon: "checkmark.circle",
                        color: theme.colors.matchPositive,
                        width: cellWidth
                    ) {
                        // Check if we should skip confirmation (final period and time expired)
                        if shouldSkipConfirmation {
                            executeEndActionDirectly()
                        } else {
                            showingEndHalfConfirmation = true
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // Compact action item for ultra-small layouts
    @ViewBuilder
    private func compactActionItem(
        title: String,
        icon: String,
        color: Color,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.xs) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36) // Smaller than standard 44pt
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium)) // Smaller icon
                        .foregroundStyle(theme.colors.textInverted)
                }

                Text(title)
                    .font(theme.typography.cardMeta) // Smaller text
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1) // Single line only
                    .minimumScaleFactor(0.7) // More aggressive scaling
            }
            .frame(width: width, height: 52) // Much smaller height than standard 72pt
            .padding(.vertical, theme.spacing.xs)
            .padding(.horizontal, theme.spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
    
    // MARK: - Helper Methods
    
    /// Computes the end action title based on current match state
    private func computeEndActionTitle() -> String {
        if matchViewModel.isFullTime {
            return "End Match"
        }
        
        if matchViewModel.isHalfTime {
            return "Start Second Half"
        }
        
        // Check if we're on the final period
        guard let match = matchViewModel.currentMatch else {
            return "End Half"
        }
        
        let isFinalPeriod = matchViewModel.currentPeriod >= match.numberOfPeriods &&
                           !match.hasExtraTime
        
        if isFinalPeriod {
            return "End Match"
        }
        
        // Show period-specific label
        if matchViewModel.currentPeriod == 1 {
            return "End 1st Half"
        } else if matchViewModel.currentPeriod == 2 {
            return "End 2nd Half"
        }
        
        return "End Half"
    }
    
    /// Checks if confirmation should be skipped (final period and time expired)
    private var shouldSkipConfirmation: Bool {
        guard let match = matchViewModel.currentMatch else {
            return false
        }
        
        // Only skip if on final period
        let isFinalPeriod = matchViewModel.currentPeriod >= match.numberOfPeriods &&
                           !match.hasExtraTime
        
        if !isFinalPeriod {
            return false
        }
        
        // Check if period time is expired
        return isPeriodTimeExpired
    }
    
    /// Checks if period time remaining is expired (<= 0)
    private var isPeriodTimeExpired: Bool {
        let timeString = matchViewModel.periodTimeRemaining
        
        // Handle "--:--" format (indicates no time limit)
        if timeString == "--:--" {
            return false
        }
        
        // Parse "MM:SS" format
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return false
        }
        
        // Check if total seconds <= 0
        return (minutes * 60 + seconds) <= 0
    }
    
    /// Executes end action directly without confirmation
    private func executeEndActionDirectly() {
        if matchViewModel.isFullTime {
            matchViewModel.finalizeMatch()
            DispatchQueue.main.async {
                lifecycle?.resetToStart()
                matchViewModel.resetMatch()
            }
            dismiss()
        } else {
            let isFirstHalf = matchViewModel.currentPeriod == 1
            matchViewModel.endCurrentPeriod()
            if isFirstHalf {
                matchViewModel.isHalfTime = true
            }
            dismiss()
        }
    }
}
