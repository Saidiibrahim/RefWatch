//
//  ContentView.swift
//  RefereeAssistant
//
//  Description: The Welcome page with two main options: "Start Match" and "Settings".
//

import SwiftUI
import RefWatchCore

struct ContentView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var appModeController: AppModeController
    @State private var matchViewModel = MatchViewModel(haptics: WatchHaptics(), connectivity: WatchConnectivitySyncClient())
    @State private var settingsViewModel = SettingsViewModel()
    @State private var lifecycle = MatchLifecycleCoordinator()
    @State private var showPersistenceError = false
    @State private var latestSummary: CompletedMatchSummary?
    private let commandHandler = LiveActivityCommandHandler()
    private let livePublisher = LiveActivityStatePublisher(reloadKind: "RefZoneWidgets")
    
    var body: some View {
        NavigationStack {
            Group {
                switch lifecycle.state {
                case .idle:
                    List {
                        heroSection
                        quickActionsSection
                    }
                    .listStyle(.carousel)
                    .scrollIndicators(.hidden)
                    .scenePadding(.horizontal)
                    .padding(.top, theme.spacing.xs)
                case .kickoffFirstHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .setup:
                    MatchSetupView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .kickoffSecondHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        isSecondHalf: true,
                        defaultSelectedTeam: (matchViewModel.getSecondHalfKickingTeam() == .home) ? .home : .away,
                        lifecycle: lifecycle
                    )
                case .kickoffExtraTimeFirstHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        extraTimePhase: 1,
                        lifecycle: lifecycle
                    )
                case .kickoffExtraTimeSecondHalf:
                    MatchKickOffView(
                        matchViewModel: matchViewModel,
                        extraTimePhase: 2,
                        defaultSelectedTeam: (matchViewModel.getETSecondHalfKickingTeam() == .home) ? .home : .away,
                        lifecycle: lifecycle
                    )
                case .choosePenaltyFirstKicker:
                    PenaltyFirstKickerView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .penalties:
                    PenaltyShootoutView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                case .finished:
                    FullTimeView(
                        matchViewModel: matchViewModel,
                        lifecycle: lifecycle
                    )
                }
            }
        }
        .environment(settingsViewModel)
        .task {
            latestSummary = matchViewModel.latestCompletedMatchSummary()
            appModeController.select(.match, persist: false)
        }
        .onOpenURL { url in
            // Deep link from Smart Stack widget
            guard url.scheme == "refzone" else { return }
            if url.host == "timer" {
                // Route into the Timer surface when a match is active; otherwise land on start
                if matchViewModel.isMatchInProgress || matchViewModel.isHalfTime || matchViewModel.penaltyShootoutActive {
                    lifecycle.goToSetup() // MatchSetupView hosts TimerView in the middle tab
                } else if matchViewModel.waitingForSecondHalfStart {
                    lifecycle.goToKickoffSecond()
                } else if matchViewModel.waitingForET1Start {
                    lifecycle.goToKickoffETFirst()
                } else if matchViewModel.waitingForET2Start {
                    lifecycle.goToKickoffETSecond()
                } else {
                    lifecycle.resetToStart()
                }
                consumeWidgetCommand()
            }
        }
        .onChange(of: matchViewModel.matchCompleted) { completed, _ in
            #if DEBUG
            print("DEBUG: ContentView.onChange matchCompleted=\(completed) state=\(lifecycle.state)")
            #endif
            // Defensive fallback to guarantee return to idle after finalize
            if completed && lifecycle.state != .idle {
                lifecycle.resetToStart()
                matchViewModel.resetMatch()
            }
            if completed {
                latestSummary = matchViewModel.latestCompletedMatchSummary()
            }
        }
        .onChange(of: lifecycle.state) { newState in
            #if DEBUG
            print("DEBUG: ContentView.onChange lifecycle.state=\(newState)")
            #endif
            if newState != .idle {
                appModeController.overrideForActiveSession(.match)
            }
        }
        .onChange(of: matchViewModel.lastPersistenceError) { newValue, _ in
            if newValue != nil { showPersistenceError = true }
        }
        .alert("Save Failed", isPresented: $showPersistenceError) {
            Button("OK") { matchViewModel.lastPersistenceError = nil }
        } message: {
            Text(matchViewModel.lastPersistenceError ?? "An unknown error occurred while saving.")
        }
    }
}

#Preview {
    ContentView()
}

private extension ContentView {
    @ViewBuilder
    var heroSection: some View {
        Section {
            NavigationLink {
                StartMatchScreen(matchViewModel: matchViewModel, lifecycle: lifecycle)
            } label: {
                StartMatchHeroCard()
            }
            .buttonStyle(.plain)
            .listRowInsets(quickActionInsets)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    var quickActionsSection: some View {
        Section {
            NavigationLink {
                MatchHistoryView(matchViewModel: matchViewModel)
            } label: {
                QuickActionLabel(
                    title: "History",
                    subtitle: historyQuickActionSubtitle,
                    icon: "clock.arrow.circlepath",
                    tint: theme.colors.accentPrimary
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(quickActionInsets)
            .listRowBackground(Color.clear)

            NavigationLink {
                SettingsScreen(settingsViewModel: settingsViewModel)
            } label: {
                QuickActionLabel(
                    title: "Settings",
                    subtitle: "Teams, alerts, and presets",
                    icon: "gear",
                    tint: theme.colors.accentMuted
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(quickActionInsets)
            .listRowBackground(Color.clear)
        }
    }

    func consumeWidgetCommand() {
        guard commandHandler.processPendingCommand(model: matchViewModel) != nil else { return }
        livePublisher.publish(for: matchViewModel)
    }

    func historySubtitle(for summary: CompletedMatchSummary) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: summary.completedAt, relativeTo: Date())
        return relative
    }

    var historyQuickActionSubtitle: String {
        guard let summary = latestSummary else { return "Review completed matches" }
        return "Last: \(summary.scoreline) · \(historySubtitle(for: summary))"
    }

    var quickActionInsets: EdgeInsets {
        let vertical = theme.spacing.xs
        return EdgeInsets(top: vertical, leading: 0, bottom: vertical, trailing: 0)
    }

}

private struct StartMatchHeroCard: View {
    @Environment(\.theme) private var theme

    var body: some View {
        MenuCard(
            title: "Start Match",
            subtitle: nil,
            icon: "flag.checkered",
            tint: theme.colors.accentPrimary,
            accessoryIcon: "chevron.forward",
            minHeight: 92
        )
    }
}

private struct QuickActionLabel: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        MenuCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            tint: tint,
            accessoryIcon: "chevron.forward",
            minHeight: 92
        )
    }
}

private struct MenuCard: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let accessoryIcon: String?
    let minHeight: CGFloat

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.components.controlCornerRadius, style: .continuous)
                    .fill(tint.opacity(0.25))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(theme.typography.iconAccent)
                    .foregroundStyle(theme.colors.textInverted)
            }

            VStack(alignment: .leading, spacing: subtitleSpacing) {
                Text(title)
                    .font(theme.typography.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            Spacer()

            if let accessoryIcon {
                Image(systemName: accessoryIcon)
                    .font(theme.typography.iconSecondary)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .padding(.vertical, theme.spacing.s)
        .padding(.horizontal, theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                .fill(theme.colors.surfaceOverlay)
        )
    }

    private var subtitleSpacing: CGFloat {
        subtitle?.isEmpty == false ? theme.spacing.xs : 0
    }
}
