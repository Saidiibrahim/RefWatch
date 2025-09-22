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
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    
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
        // Use a simple VStack to avoid scroll overlap issues and keep
        // the bottom controls consistently positioned on all sizes.
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            header

            HStack(spacing: theme.spacing.s) {
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

            Spacer(minLength: theme.spacing.s)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.top, theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            // Keep the duration chip visually associated with the confirm action
            // by placing both inside the safe-area inset, stacked vertically.
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                durationChip
                confirmButton
            }
            .padding(.horizontal, theme.spacing.m)
            .padding(.bottom, layout.safeAreaBottomPadding)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(screenTitle)
                .font(theme.typography.heroSubtitle)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var durationChip: some View {
        Button {
            lifecycle.requestStartMatchScreen()
        } label: {
            Text(perPeriodDurationLabel)
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, theme.spacing.xs)
                .padding(.horizontal, theme.spacing.s)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.colors.backgroundElevated.opacity(0.6))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("kickoffDurationChip")
    }

    // Note: No additional bottom content padding is required now that
    // the duration chip and confirm button are placed inside the inset.

    private var confirmButton: some View {
        IconButton(
            icon: "checkmark.circle.fill",
            color: selectedTeam != nil
                ? theme.colors.matchPositive
                : theme.colors.matchPositive.opacity(0.35)
        ) { confirmKickOff() }
        .disabled(selectedTeam == nil)
        .accessibilityIdentifier("kickoffConfirmButton")
        .animation(.easeInOut(duration: 0.2), value: selectedTeam != nil)
    }

    private func confirmKickOff() {
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
            matchViewModel.setKickingTeam(team == .home)
            matchViewModel.startMatch()
            lifecycle.goToSetup()
        }
    }
}

#Preview("Kickoff – 41mm") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    let lifecycle = MatchLifecycleCoordinator()
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)

    return MatchKickOffView(matchViewModel: viewModel, lifecycle: lifecycle)
        .watchLayoutScale(WatchLayoutScale(category: .compact))
        .previewDevice("Apple Watch Series 9 (41mm)")
}

#Preview("Kickoff – Ultra") {
    let viewModel = MatchViewModel(haptics: WatchHaptics())
    viewModel.configureMatch(duration: 120, periods: 2, halfTimeLength: 15, hasExtraTime: true, hasPenalties: true)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    let lifecycle = MatchLifecycleCoordinator()

    return MatchKickOffView(matchViewModel: viewModel, isSecondHalf: true, defaultSelectedTeam: .away, lifecycle: lifecycle)
        .watchLayoutScale(WatchLayoutScale(category: .expanded))
        .previewDevice("Apple Watch Ultra 2 (49mm)")
}
