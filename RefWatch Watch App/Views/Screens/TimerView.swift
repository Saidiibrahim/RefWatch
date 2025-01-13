// TimerView.swift
// Description: Main match timing screen with swipeable layout for team events

import SwiftUI

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
                
                Text(model.periodTime)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            
            // Controls
            if model.isMatchInProgress {
                HStack(spacing: 20) {
                    Button(action: {
                        if model.isPaused {
                            model.resumeMatch()
                        } else {
                            model.pauseMatch()
                        }
                    }) {
                        Image(systemName: model.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title2)
                    }
                    .tint(model.isPaused ? .green : .orange)
                    
                    if model.isPaused && !model.isHalfTime {
                        Button(action: {
                            model.startNextPeriod()
                        }) {
                            Image(systemName: "forward.circle.fill")
                                .font(.title2)
                        }
                        .tint(.blue)
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