// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import SwiftUI
import WatchKit

struct TimerView: View {
    let model: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @State private var showingActionSheet = false
    @State private var pendingRouteToChooseFirstKicker = false
    @Environment(\.dismiss) private var dismiss
    
    private var periodLabel: String {
        if model.isHalfTime && !model.waitingForHalfTimeStart {
            return "Half Time"
        } else if model.waitingForHalfTimeStart {
            return "Half Time"
        } else if model.waitingForSecondHalfStart {
            return "Second Half"
        } else {
            switch model.currentPeriod {
            case 1: return "First Half"
            case 2: return "Second Half"
            case 3: return "Extra Time 1"
            case 4: return "Extra Time 2"
            default: return "Penalties"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
                // Period indicator
                HStack {
                    Text(periodLabel)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                
                // Score display
                ScoreDisplayView(
                    homeTeam: model.homeTeam,
                    awayTeam: model.awayTeam,
                    homeScore: model.currentMatch?.homeScore ?? 0,
                    awayScore: model.currentMatch?.awayScore ?? 0
                )
                
                // Main content based on match state
                if model.isHalfTime {
                    halfTimeView
                } else {
                    runningMatchView
                }
        }
        .accessibilityIdentifier("timerArea")
        .padding(.top)
        .onLongPressGesture(minimumDuration: 0.8) {
            // Allow long press when match is running or during half-time
            if model.isMatchInProgress || model.isHalfTime {
                WKInterfaceDevice.current().play(.notification)
                showingActionSheet = true
            }
        }
        .sheet(isPresented: $showingActionSheet, onDismiss: {
            #if DEBUG
            print("DEBUG: TimerView.sheet onDismiss showingActionSheet=false, pendingRouteToChooseFirstKicker=\(pendingRouteToChooseFirstKicker), waitingForPenaltiesStart=\(model.waitingForPenaltiesStart)")
            #endif
            // Modal presentation race prevention for watchOS:
            // When penalties should start while the actions sheet is visible, defer
            // navigation until after the sheet dismisses to avoid PUICAlertSheetController
            // overlap and the "already presenting" crash on watchOS.
            // We set `pendingRouteToChooseFirstKicker` while the sheet is open; on
            // dismissal we clear the flag and route exactly once.
            if pendingRouteToChooseFirstKicker || model.waitingForPenaltiesStart {
                pendingRouteToChooseFirstKicker = false
                lifecycle.goToChoosePenaltyFirstKicker()
            }
        }) {
            MatchActionsSheet(matchViewModel: model, lifecycle: lifecycle)
        }
        // Lifecycle routing hooks
        .onChange(of: model.isFullTime) { isFT in
            #if DEBUG
            print("DEBUG: TimerView.onChange isFullTime=\(isFT) state=\(lifecycle.state) matchCompleted=\(model.matchCompleted)")
            #endif
            // Guard against re-entering finished after finalize/reset
            if isFT && !model.matchCompleted && lifecycle.state != .idle {
                lifecycle.goToFinished()
            }
        }
        .onChange(of: model.waitingForSecondHalfStart) { waiting in
            if waiting { lifecycle.goToKickoffSecond() }
        }
        .onChange(of: model.waitingForET1Start) { waiting in
            if waiting { lifecycle.goToKickoffETFirst() }
        }
        .onChange(of: model.waitingForET2Start) { waiting in
            if waiting { lifecycle.goToKickoffETSecond() }
        }
        .onChange(of: model.waitingForPenaltiesStart) { waiting in
            #if DEBUG
            print("DEBUG: TimerView.onChange waitingForPenaltiesStart=\(waiting) sheetShown=\(showingActionSheet)")
            #endif
            if waiting {
                if showingActionSheet {
                    pendingRouteToChooseFirstKicker = true
                } else {
                    lifecycle.goToChoosePenaltyFirstKicker()
                }
            }
        }
    }
    
    // MARK: - State-specific Views
    
    
    @ViewBuilder
    private var halfTimeView: some View {
        if model.waitingForHalfTimeStart {
            // Show large circular button matching the screenshot
            Spacer()
            
            IconButton(
                icon: "checkmark",
                color: Color(red: 0.78, green: 0.90, blue: 0.19), // Yellow-green color
                size: 70,
                action: {
                    WKInterfaceDevice.current().play(.start)
                    model.startHalfTimeManually()
                }
            )
            .padding(.bottom, 20)
            
            Spacer()
        } else {
            // Show only the timer counting up (matching second screenshot)
            Text(model.halfTimeElapsed)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.vertical, 40)
        }
    }
    
    @ViewBuilder
    private var runningMatchView: some View {
        VStack(spacing: 4) {
            Text(model.matchTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            // Countdown timer (remaining time in period)
            Text(model.periodTimeRemaining)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.gray)
            
            // Stoppage time (when active)
            if model.isInStoppage {
                Text("+\(model.formattedStoppageTime)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .onTapGesture {
            // Haptic feedback
            WKInterfaceDevice.current().play(.click)
            
            if model.isPaused {
                model.resumeMatch()
            } else {
                model.pauseMatch()
            }
        }
        
        // Visual indicator for pause state
        if model.isMatchInProgress && model.isPaused {
            VStack(spacing: 8) {
                Text("PAUSED")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Tap to resume")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                // Show period advance option during pause
                if !model.isHalfTime {
                    Button(action: {
                        model.startNextPeriod()
                    }) {
                        HStack {
                            Image(systemName: "forward.fill")
                            Text("Next Period")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
}

// MARK: - Supporting Views

#Preview {
    TimerView(model: MatchViewModel(haptics: WatchHaptics()), lifecycle: MatchLifecycleCoordinator())
} 
