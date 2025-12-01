//
//  MatchPeriodActionButton.swift
//  RefZoneWatchOS
//
//  Description: State-aware CTA button component for ending halves and matches
//

import SwiftUI
import WatchKit
import RefWatchCore

/// State-aware button component that displays context-appropriate actions for period transitions
struct MatchPeriodActionButton: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    
    @State private var showingEndHalfConfirmation = false
    @State private var showingEndMatchConfirmation = false
    
    var body: some View {
        // Only show button when match is active or in transition states
        if shouldShowButton {
            Button(action: handleButtonAction) {
                Label(buttonTitle, systemImage: buttonIcon)
                    .font(theme.typography.cardHeadline)
                    .foregroundStyle(theme.colors.textInverted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.s)
                    .padding(.horizontal, theme.components.cardHorizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius)
                            .fill(theme.colors.matchPositive)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .padding(.top, theme.spacing.s)
            .confirmationDialog(
                "",
                isPresented: $showingEndHalfConfirmation,
                titleVisibility: .hidden
            ) {
                Button("Yes") {
                    executeEndHalf()
                }
                Button("No", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
            .confirmationDialog(
                "",
                isPresented: $showingEndMatchConfirmation,
                titleVisibility: .hidden
            ) {
                Button("Yes") {
                    executeEndMatch()
                }
                Button("No", role: .cancel) { }
            } message: {
                Text("Are you sure you want to 'End Match'?")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Determines if the button should be visible
    private var shouldShowButton: Bool {
        // Show during match in progress
        if matchViewModel.isMatchInProgress {
            return true
        }
        
        // Show during half-time break
        if matchViewModel.isHalfTime {
            return true
        }
        
        // Show when waiting for transitions
        if matchViewModel.waitingForHalfTimeStart ||
           matchViewModel.waitingForSecondHalfStart ||
           matchViewModel.waitingForET1Start ||
           matchViewModel.waitingForET2Start {
            return true
        }
        
        // Show when full-time
        if matchViewModel.isFullTime {
            return true
        }
        
        return false
    }
    
    /// Returns the appropriate button title based on current state
    private var buttonTitle: String {
        // Full-time state
        if matchViewModel.isFullTime {
            return "Complete Match"
        }
        
        // Waiting for half-time to start (after ending first half)
        if matchViewModel.waitingForHalfTimeStart {
            return "Start Half-time"
        }
        
        // During half-time break, waiting to start second half
        if matchViewModel.isHalfTime {
            return "Start Second Half"
        }
        
        // Waiting for second half start (after manually ending half-time break)
        if matchViewModel.waitingForSecondHalfStart {
            return "Start Second Half"
        }
        
        // Waiting for extra time periods
        if matchViewModel.waitingForET1Start {
            return "Start Extra Time 1st Half"
        }
        
        if matchViewModel.waitingForET2Start {
            return "Start Extra Time 2nd Half"
        }
        
        // During active match - determine if ending half or match
        if matchViewModel.isMatchInProgress {
            guard let match = matchViewModel.currentMatch else {
                return "End Half"
            }
            
            // Check if this is the final period
            let isFinalPeriod = matchViewModel.currentPeriod >= match.numberOfPeriods &&
                               !match.hasExtraTime
            
            if isFinalPeriod {
                return "End Match"
            } else {
                // Show period-specific label
                if matchViewModel.currentPeriod == 1 {
                    return "End 1st Half"
                } else if matchViewModel.currentPeriod == 2 {
                    return "End 2nd Half"
                } else {
                    return "End Half"
                }
            }
        }
        
        return "End Half"
    }
    
    /// Returns the appropriate icon based on current state
    private var buttonIcon: String {
        if matchViewModel.isFullTime {
            return "checkmark.circle.fill"
        }
        
        if matchViewModel.isHalfTime || 
           matchViewModel.waitingForHalfTimeStart ||
           matchViewModel.waitingForSecondHalfStart ||
           matchViewModel.waitingForET1Start ||
           matchViewModel.waitingForET2Start {
            return "arrow.right.circle.fill"
        }
        
        return "checkmark.circle.fill"
    }
    
    /// Returns confirmation message for ending half
    private var confirmationMessage: String {
        guard let match = matchViewModel.currentMatch else {
            return "Are you sure you want to 'End Half'?"
        }
        
        // Check if this is the final period
        let isFinalPeriod = matchViewModel.currentPeriod >= match.numberOfPeriods &&
                           !match.hasExtraTime
        
        if isFinalPeriod {
            return "Are you sure you want to 'End Match'?"
        }
        
        return "Are you sure you want to 'End Half'?"
    }
    
    // MARK: - Actions
    
    /// Handles button tap based on current state
    private func handleButtonAction() {
        WKInterfaceDevice.current().play(.click)
        
        // Full-time: show confirmation and finalize
        if matchViewModel.isFullTime {
            showingEndMatchConfirmation = true
            return
        }
        
        // Waiting for half-time start: start half-time manually
        if matchViewModel.waitingForHalfTimeStart {
            matchViewModel.startHalfTimeManually()
            return
        }
        
        // During half-time: end half-time and start second half
        if matchViewModel.isHalfTime {
            matchViewModel.endHalfTimeManually()
            return
        }
        
        // Waiting for second half start: start second half manually
        if matchViewModel.waitingForSecondHalfStart {
            matchViewModel.startSecondHalfManually()
            return
        }
        
        // Waiting for extra time periods
        if matchViewModel.waitingForET1Start {
            matchViewModel.startExtraTimeFirstHalfManually()
            return
        }
        
        if matchViewModel.waitingForET2Start {
            matchViewModel.startExtraTimeSecondHalfManually()
            return
        }
        
        // During active match: check if we should skip confirmation
        if matchViewModel.isMatchInProgress {
            guard let match = matchViewModel.currentMatch else {
                showingEndHalfConfirmation = true
                return
            }
            
            // Check if this is the final period and time is expired
            let isFinalPeriod = matchViewModel.currentPeriod >= match.numberOfPeriods &&
                               !match.hasExtraTime
            
            if isFinalPeriod && isPeriodTimeExpired {
                // Skip confirmation and end match directly
                executeEndMatch()
            } else {
                // Show confirmation for ending half
                showingEndHalfConfirmation = true
            }
            return
        }
    }
    
    /// Executes end half action after confirmation
    private func executeEndHalf() {
        guard let match = matchViewModel.currentMatch else { return }
        
        let isFirstHalf = matchViewModel.currentPeriod == 1
        matchViewModel.endCurrentPeriod()
        
        if isFirstHalf {
            matchViewModel.isHalfTime = true
        }
    }
    
    /// Executes end match action after confirmation
    private func executeEndMatch() {
        matchViewModel.finalizeMatch()
        DispatchQueue.main.async {
            lifecycle.resetToStart()
            matchViewModel.resetMatch()
        }
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
}

#Preview("End 1st Half") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.isMatchInProgress = true
    viewModel.currentPeriod = 1
    
    return MatchPeriodActionButton(
        matchViewModel: viewModel,
        lifecycle: MatchLifecycleCoordinator()
    )
    .watchLayoutScale(WatchLayoutScale(category: .compact))
    
}

#Preview("Start Second Half") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.isHalfTime = true
    viewModel.waitingForSecondHalfStart = true
    
    return MatchPeriodActionButton(
        matchViewModel: viewModel,
        lifecycle: MatchLifecycleCoordinator()
    )
    .watchLayoutScale(WatchLayoutScale(category: .compact))
    
}

#Preview("End Match") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.isFullTime = true
    
    return MatchPeriodActionButton(
        matchViewModel: viewModel,
        lifecycle: MatchLifecycleCoordinator()
    )
    .watchLayoutScale(WatchLayoutScale(category: .compact))
    
}

