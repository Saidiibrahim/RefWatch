// MatchKickOffView.swift
// Description: Screen shown before match/period start to select kicking team

import SwiftUI

struct MatchKickOffView: View {
    let matchViewModel: MatchViewModel
    let isSecondHalf: Bool
    let defaultSelectedTeam: Team?
    let lifecycle: MatchLifecycleCoordinator
    
    @State private var selectedTeam: Team?
    
    enum Team {
        case home, away
    }
    
    // Convenience initializer for first half (original usage)
    init(matchViewModel: MatchViewModel, lifecycle: MatchLifecycleCoordinator) {
        self.matchViewModel = matchViewModel
        self.isSecondHalf = false
        self.defaultSelectedTeam = nil
        self.lifecycle = lifecycle
        // Initialize @State with nil for first half
        self._selectedTeam = State(initialValue: nil)
    }
    
    // Initializer for second half usage
    init(matchViewModel: MatchViewModel, isSecondHalf: Bool, defaultSelectedTeam: Team, lifecycle: MatchLifecycleCoordinator) {
        self.matchViewModel = matchViewModel
        self.isSecondHalf = isSecondHalf
        self.defaultSelectedTeam = defaultSelectedTeam
        self.lifecycle = lifecycle
        // Initialize @State with nil - will be set in onAppear
        self._selectedTeam = State(initialValue: nil)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with time and kick off text (right-aligned)
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(formattedCurrentTime)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(isSecondHalf ? "Second Half" : "Kick off")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
            // Team selection boxes (horizontal layout)
            HStack(spacing: 12) {
                SimpleTeamBox(
                    teamName: matchViewModel.currentMatch?.homeTeam ?? "HOM",
                    score: matchViewModel.currentMatch?.homeScore ?? 0,
                    isSelected: selectedTeam == .home,
                    action: { selectedTeam = .home },
                    accessibilityIdentifier: "homeTeamButton"
                )
                
                SimpleTeamBox(
                    teamName: matchViewModel.currentMatch?.awayTeam ?? "AWA", 
                    score: matchViewModel.currentMatch?.awayScore ?? 0,
                    isSelected: selectedTeam == .away,
                    action: { selectedTeam = .away },
                    accessibilityIdentifier: "awayTeamButton"
                )
            }
            .padding(.horizontal)
            
            // Duration button
            Button(action: { }) {
                CompactButton(
                    title: perPeriodDurationLabel,
                    style: .secondary
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Start button (simple green circle with checkmark)
            Button {
                guard let team = selectedTeam else { return }
                if isSecondHalf {
                    matchViewModel.setKickingTeam(team == .home)
                    matchViewModel.startSecondHalfManually()
                    lifecycle.goToSetup()
                } else {
                    // First half: match already configured in CreateMatchView
                    matchViewModel.setKickingTeam(team == .home)
                    matchViewModel.startMatch()
                    lifecycle.goToSetup()
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(selectedTeam != nil ? Color.green : Color.gray)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedTeam == nil)
            .accessibilityIdentifier("kickoffConfirmButton")
            .padding(.bottom, 12)
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            // Set the default selected team for second half
            if isSecondHalf, let defaultTeam = defaultSelectedTeam {
                selectedTeam = defaultTeam
            }
        }
    }
    
    // Computed property for current time
    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }

    // Per-period duration label derived from current match when available
    private var perPeriodDurationLabel: String {
        if let m = matchViewModel.currentMatch {
            let periods = max(1, m.numberOfPeriods)
            let per = m.duration / TimeInterval(periods)
            let perClamped = max(0, per)
            let mm = Int(perClamped) / 60
            let ss = Int(perClamped) % 60
            return String(format: "%02d:%02d ▼", mm, ss)
        } else {
            return "\(matchViewModel.matchDuration/2):00 ▼"
        }
    }
}

// Simple team box component matching target design
private struct SimpleTeamBox: View {
    let teamName: String
    let score: Int
    let isSelected: Bool
    let action: () -> Void
    let accessibilityIdentifier: String?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(teamName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier ?? "teamBox_\(teamName)")
    }
} 
