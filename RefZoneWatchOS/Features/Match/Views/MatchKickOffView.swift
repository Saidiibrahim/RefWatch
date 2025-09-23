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
    @State private var isShowingMatchSettings = false
    @State private var isShowingDurationDialog = false
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
        GeometryReader { _ in
            ViewThatFits(in: .vertical) {
                fullLayout
                compactLayout
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            confirmButton
                .padding(.top, confirmButtonTopPadding) // Use responsive padding
                .padding(.horizontal, theme.spacing.m)
                .padding(.bottom, layout.safeAreaBottomPadding)
        }
        .sheet(isPresented: $isShowingMatchSettings) {
            NavigationStack {
                MatchSettingsListView(
                    matchViewModel: matchViewModel,
                    primaryActionLabel: "Apply Settings"
                ) { viewModel in
                    viewModel.applySettingsToCurrentMatch(
                        durationMinutes: viewModel.matchDuration,
                        periods: viewModel.numberOfPeriods,
                        halfTimeLengthMinutes: viewModel.halfTimeLength,
                        hasExtraTime: viewModel.hasExtraTime,
                        hasPenalties: viewModel.hasPenalties,
                        extraTimeHalfLengthMinutes: viewModel.extraTimeHalfLengthMinutes,
                        penaltyRounds: viewModel.penaltyInitialRounds
                    )
                }
            }
        }
        .confirmationDialog(
            "Half Duration",
            isPresented: $isShowingDurationDialog,
            presenting: allowsDurationShortcut ? perPeriodDurationLabel : nil,
            actions: { _ in
                Button("Change Duration") {
                    isShowingDurationDialog = false
                    isShowingMatchSettings = true
                }
                Button("Cancel", role: .cancel) {}
            },
            message: { durationLabel in
                Text(durationLabel)
            }
        )
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

    private var fullLayout: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            header

            // Team buttons section
            VStack(spacing: theme.spacing.m) {
                HStack(spacing: theme.spacing.m) {
                    kickoffTeamButton(
                        title: matchViewModel.homeTeamDisplayName,
                        score: matchViewModel.currentMatch?.homeScore ?? 0,
                        isSelected: selectedTeam == .home,
                        action: { selectedTeam = .home },
                        accessibilityIdentifier: "homeTeamButton"
                    )
                    .accessibilityLabel("Home")

                    kickoffTeamButton(
                        title: matchViewModel.awayTeamDisplayName,
                        score: matchViewModel.currentMatch?.awayScore ?? 0,
                        isSelected: selectedTeam == .away,
                        action: { selectedTeam = .away },
                        accessibilityIdentifier: "awayTeamButton"
                    )
                    .accessibilityLabel("Away")
                }
            }

            Spacer(minLength: theme.spacing.l)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.top, theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            header

            // Team buttons section with tighter spacing
            VStack(spacing: theme.spacing.s) {
                HStack(spacing: theme.spacing.s) {
                    kickoffTeamButton(
                        title: matchViewModel.homeTeamDisplayName,
                        score: matchViewModel.currentMatch?.homeScore ?? 0,
                        isSelected: selectedTeam == .home,
                        action: { selectedTeam = .home },
                        accessibilityIdentifier: "homeTeamButton"
                    )
                    .accessibilityLabel("Home")

                    kickoffTeamButton(
                        title: matchViewModel.awayTeamDisplayName,
                        score: matchViewModel.currentMatch?.awayScore ?? 0,
                        isSelected: selectedTeam == .away,
                        action: { selectedTeam = .away },
                        accessibilityIdentifier: "awayTeamButton"
                    )
                    .accessibilityLabel("Away")
                }
            }

            Spacer(minLength: theme.spacing.xs)
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.top, theme.spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kickoffTeamButton(
        title: String,
        score: Int,
        isSelected: Bool,
        action: @escaping () -> Void,
        accessibilityIdentifier: String
    ) -> some View {
        CompactTeamBox(
            teamName: title,
            score: score,
            isSelected: isSelected,
            action: action,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    // Responsive spacing for confirm button - more space needed on smaller screens
    private var confirmButtonTopPadding: CGFloat {
        switch layout.category {
        case .compact:
            return theme.spacing.xl // 24pt on compact screens for better visual balance
        case .standard:
            return theme.spacing.l  // 16pt on standard screens
        case .expanded:
            return theme.spacing.l  // 16pt on expanded screens (Ultra looks good already)
        }
    }

    // Note: No additional bottom content padding is required now that
    // the duration chip and confirm button are placed inside the inset.

    private var confirmButton: some View {
        ZStack {
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
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8)
                .onEnded { _ in
                    guard allowsDurationShortcut else { return }
                    isShowingDurationDialog = true
                }
        )
    }

    private var allowsDurationShortcut: Bool {
        if isSecondHalf { return false }
        if let phase = etPhase, phase != 1 { return false }
        return true
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
