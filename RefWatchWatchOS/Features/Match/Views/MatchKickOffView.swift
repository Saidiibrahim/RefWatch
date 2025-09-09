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
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header - more compact with improved font size
                Text(screenTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                Spacer(minLength: 8)
                
                // Team selection boxes - more compact layout
                HStack(spacing: 10) {
                    CompactTeamBox(
                        teamName: matchViewModel.homeTeamDisplayName,
                        score: matchViewModel.currentMatch?.homeScore ?? 0,
                        isSelected: selectedTeam == .home,
                        action: { selectedTeam = .home },
                        accessibilityIdentifier: "homeTeamButton"
                    )
                    .accessibilityLabel("Home")
                    
                    CompactTeamBox(
                        teamName: matchViewModel.awayTeamDisplayName,
                        score: matchViewModel.currentMatch?.awayScore ?? 0,
                        isSelected: selectedTeam == .away,
                        action: { selectedTeam = .away },
                        accessibilityIdentifier: "awayTeamButton"
                    )
                    .accessibilityLabel("Away")
                }
                .padding(.horizontal)
                
                Spacer(minLength: 8)
                
                // Duration display - inline text instead of button
                Text(perPeriodDurationLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal)
                
                Spacer(minLength: 12)
                
                // Start button - optimized size for better fit
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
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(selectedTeam != nil ? Color.green : Color.gray)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedTeam == nil)
                .accessibilityIdentifier("kickoffConfirmButton")
                
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarBackButtonHidden()
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

// Compact team box component optimized for watch screen space
private struct CompactTeamBox: View {
    let teamName: String
    let score: Int
    let isSelected: Bool
    let action: () -> Void
    let accessibilityIdentifier: String?
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(teamName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 65) // Reduced from 80pt for better fit
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.green : Color.gray.opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier ?? "teamBox_\(teamName)")
    }
} 
