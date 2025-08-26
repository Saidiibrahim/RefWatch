// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import SwiftUI
import WatchKit

struct TimerView: View {
    let model: MatchViewModel
    @State private var showingActionSheet = false
    
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
        if model.waitingForSecondHalfStart {
            // Show ONLY MatchKickOffView - no wrapping UI
            MatchKickOffView(
                matchViewModel: model,
                isSecondHalf: true,
                defaultSelectedTeam: model.getSecondHalfKickingTeam()
            )
        } else {
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
                if model.waitingForMatchStart {
                    waitingForMatchStartView
                } else if model.waitingForHalfTimeStart {
                    waitingForHalfTimeView
                } else if model.isHalfTime {
                    halfTimeView
                } else {
                    runningMatchView
                }
            }
            .padding(.top)
            .onLongPressGesture(minimumDuration: 0.8) {
                // Allow long press when match is running or during half-time
                if model.isMatchInProgress || model.isHalfTime {
                    WKInterfaceDevice.current().play(.notification)
                    showingActionSheet = true
                }
            }
            .sheet(isPresented: $showingActionSheet) {
                MatchActionsSheet(matchViewModel: model)
            }
        }
    }
    
    // MARK: - State-specific Views
    
    @ViewBuilder
    private var waitingForMatchStartView: some View {
        VStack(spacing: 16) {
            Text("00:00")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.gray)
            
            Text("Ready to start")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Button(action: {
                WKInterfaceDevice.current().play(.start)
                model.startMatch()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var waitingForHalfTimeView: some View {
        VStack(spacing: 16) {
            Text(model.matchTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.gray)
            
            Text("Ready for half-time")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Button(action: {
                WKInterfaceDevice.current().play(.start)
                model.startHalfTimeManually()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }
    
    
    @ViewBuilder
    private var halfTimeView: some View {
        VStack(spacing: 4) {
            Text(model.halfTimeElapsed)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.orange)
            
            Text("Half-time break")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
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
    TimerView(model: MatchViewModel())
} 