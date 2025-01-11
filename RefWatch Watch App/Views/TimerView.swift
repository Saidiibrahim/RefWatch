// TimerView.swift
// Description: View for displaying match time and controls.

import SwiftUI

struct TimerView: View {
    let model: MatchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Match time
            Text(model.matchTime)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            
            // Period time
            Text(model.periodTime)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.gray)
            
            // Half-time countdown if active
            if model.isHalfTime {
                Text("Half Time: \(model.halfTimeRemaining)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            // Period indicator
            Text("Period \(model.currentPeriod)")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Controls
            HStack(spacing: 20) {
                if model.isMatchInProgress {
                    // Pause/Resume button
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
                    
                    // Next period button (only show if paused)
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
        .padding()
    }
}

#Preview {
    TimerView(model: MatchViewModel())
} 