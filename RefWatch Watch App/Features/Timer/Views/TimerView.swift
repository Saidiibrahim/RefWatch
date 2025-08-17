// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import SwiftUI
import WatchKit

struct TimerView: View {
    let model: MatchViewModel
    
    private var periodLabel: String {
        switch model.currentPeriod {
        case 1: return "First Half"
        case 2: return "Second Half"
        case 3: return "Extra Time 1"
        case 4: return "Extra Time 2"
        default: return "Penalties"
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
            
            // Main time display
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
        .padding(.top)
    }
}

#Preview {
    TimerView(model: MatchViewModel())
} 