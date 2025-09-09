// MatchKickOffView.swift
// Description: Screen shown before match/period start to select kicking team

import SwiftUI
import RefWatchCore

struct MatchKickOffView: View {
    let matchViewModel: MatchViewModel
    let isSecondHalf: Bool
    let defaultSelectedTeam: Team?
    let etPhase: Int? // 1 or 2 for Extra Time phases; nil for regulation
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
        self.etPhase = nil
        self.lifecycle = lifecycle
        // Initialize @State with nil for first half
        self._selectedTeam = State(initialValue: nil)
    }
    
    // Initializer for second half usage
    init(matchViewModel: MatchViewModel, isSecondHalf: Bool, defaultSelectedTeam: Team, lifecycle: MatchLifecycleCoordinator) {
        self.matchViewModel = matchViewModel
        self.isSecondHalf = isSecondHalf
        self.defaultSelectedTeam = defaultSelectedTeam
        self.etPhase = nil
        self.lifecycle = lifecycle
        // Initialize @State with nil - will be set in onAppear
        self._selectedTeam = State(initialValue: nil)
    }

    // Initializer for Extra Time kickoff (phase 1 or 2)
    init(matchViewModel: MatchViewModel, extraTimePhase: Int, lifecycle: MatchLifecycleCoordinator) {
        self.matchViewModel = matchViewModel
        self.isSecondHalf = false
        self.defaultSelectedTeam = nil
        self.etPhase = extraTimePhase
        self.lifecycle = lifecycle
        self._selectedTeam = State(initialValue: nil)
    }

    // Initializer for Extra Time second half with default team
    init(matchViewModel: MatchViewModel, extraTimePhase: Int, defaultSelectedTeam: Team, lifecycle: MatchLifecycleCoordinator) {
        self.matchViewModel = matchViewModel
        self.isSecondHalf = false
        self.defaultSelectedTeam = defaultSelectedTeam
        self.etPhase = extraTimePhase
        self.lifecycle = lifecycle
        self._selectedTeam = State(initialValue: nil)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
            
            // Team selection boxes (horizontal layout)
            HStack(spacing: 12) {
                SimpleTeamBox(
                    teamName: matchViewModel.homeTeamDisplayName,
                    score: matchViewModel.currentMatch?.homeScore ?? 0,
                    isSelected: selectedTeam == .home,
                    action: { selectedTeam = .home },
                    accessibilityIdentifier: "homeTeamButton"
                )
                .accessibilityLabel("Home")
                
                SimpleTeamBox(
                    teamName: matchViewModel.awayTeamDisplayName, 
                    score: matchViewModel.currentMatch?.awayScore ?? 0,
                    isSelected: selectedTeam == .away,
                    action: { selectedTeam = .away },
                    accessibilityIdentifier: "awayTeamButton"
                )
                .accessibilityLabel("Away")
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
                if let phase = etPhase {
                    if phase == 1 {
                        matchViewModel.setKickingTeamET1(team == .home)
                        matchViewModel.startExtraTimeFirstHalfManually()
                        lifecycle.goToSetup()
                    } else {
                        matchViewModel.startExtraTimeSecondHalfManually()
                        lifecycle.goToSetup()
                    }
                } else if isSecondHalf {
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
            .safeAreaPadding(.top, 8)
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(screenTitle)
        .onAppear {
            // Set the default selected team for second half
            if isSecondHalf, let defaultTeam = defaultSelectedTeam {
                selectedTeam = defaultTeam
            }
            // Set default for ET second half if provided
            if let phase = etPhase, phase == 2, let defaultTeam = defaultSelectedTeam {
                selectedTeam = defaultTeam
            }
        }
    }
    
    private var screenTitle: String {
        if let phase = etPhase {
            return phase == 1 ? "ET 1" : "ET 2"
        }
        return isSecondHalf ? "Second Half" : "Kick Off"
    }

    // Per-period duration label derived from current match when available
    private var perPeriodDurationLabel: String {
        if let m = matchViewModel.currentMatch {
            // Use ET half length when in Extra Time kickoff
            if let _ = etPhase {
                let et = max(0, Int(m.extraTimeHalfLength))
                let mm = et / 60
                let ss = et % 60
                return String(format: "%02d:%02d ▼", mm, ss)
            } else {
                let periods = max(1, m.numberOfPeriods)
                let per = m.duration / TimeInterval(periods)
                let perClamped = max(0, per)
                let mm = Int(perClamped) / 60
                let ss = Int(perClamped) % 60
                return String(format: "%02d:%02d ▼", mm, ss)
            }
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
