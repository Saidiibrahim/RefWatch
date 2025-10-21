//
//  MatchRootView.swift
//  RefereeAssistant
//
//  Description: The Match mode home with quick actions and lifecycle routing.
//

import SwiftUI
import Combine
import RefWatchCore

struct MatchRootView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var appModeController: AppModeController
    @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment
    @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
    @State private var backgroundRuntimeController: BackgroundRuntimeSessionController
    @State private var matchViewModel: MatchViewModel
    @State private var settingsViewModel: SettingsViewModel
    @State private var lifecycle: MatchLifecycleCoordinator
    @State private var showPersistenceError = false
    @State private var latestSummary: CompletedMatchSummary?
    @State private var navigationPath: [MatchRoute] = []
    private let commandHandler = LiveActivityCommandHandler()
    private let livePublisher = LiveActivityStatePublisher(reloadKind: "RefZoneWidgets")
    private let navigationReducer = MatchNavigationReducer()
    
    @MainActor
    init(matchViewModel: MatchViewModel? = nil, connectivity: ConnectivitySyncProviding? = nil) {
        let runtimeController = BackgroundRuntimeSessionController()
        _backgroundRuntimeController = State(initialValue: runtimeController)
        if let matchViewModel {
            _matchViewModel = State(initialValue: matchViewModel)
        } else {
            _matchViewModel = State(initialValue: MatchViewModel(
                haptics: WatchHaptics(),
                backgroundRuntime: runtimeController,
                connectivity: connectivity
            ))
        }
        _settingsViewModel = State(initialValue: SettingsViewModel())
        _lifecycle = State(initialValue: MatchLifecycleCoordinator())
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch lifecycle.state {
                case .idle:
                    List {
                        heroSection
                        quickActionsSection
                    }
                    .listStyle(.carousel)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .scenePadding(.horizontal)
                    .padding(.vertical, theme.components.listVerticalSpacing)
                    .background(theme.colors.backgroundPrimary)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if lifecycle.state == .idle {
                        Button {
                            modeSwitcherPresentation.wrappedValue = true
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                    }
                }
            }
            .navigationDestination(for: MatchRoute.self) { route in
                destination(for: route)
            }
        }
        .environment(settingsViewModel)
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .task {
            latestSummary = matchViewModel.latestCompletedMatchSummary()
        }
        .task {
            matchViewModel.updateLibrary(with: aggregateEnvironment.librarySnapshot)
        }
        .onReceive(aggregateEnvironment.$librarySnapshot) { snapshot in
            matchViewModel.updateLibrary(with: snapshot)
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
                    setNavigationPath(for: .startFlow)
                }
                consumeWidgetCommand()
            }
        }
        .onChange(of: matchViewModel.matchCompleted) { completed, _ in
            #if DEBUG
            print("DEBUG: MatchRootView.onChange matchCompleted=\(completed) state=\(lifecycle.state)")
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
        .onChange(of: lifecycle.state) { oldState, newState in
            #if DEBUG
            print("DEBUG: MatchRootView lifecycle transition: \(oldState) → \(newState)")
            print("DEBUG: Navigation path before: \(navigationPath)")
            #endif

            handleLifecycleNavigation(from: oldState, to: newState)

            #if DEBUG
            print("DEBUG: Navigation path after: \(navigationPath)")
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
    MatchRootView()
}

private extension MatchRootView {
    @ViewBuilder
    var heroSection: some View {
        Section {
            Button {
                setNavigationPath(for: .startFlow)
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
                    subtitle: nil,
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
                    subtitle: nil,
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

    var quickActionInsets: EdgeInsets {
        let vertical = theme.components.listRowVerticalInset
        let horizontal = theme.components.cardHorizontalPadding
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    func setNavigationPath(for route: MatchRoute) {
        navigationPath = route.canonicalPath
    }

    @ViewBuilder
    func destination(for route: MatchRoute) -> some View {
        switch route {
        case .startFlow:
            StartMatchScreen(
                matchViewModel: matchViewModel,
                lifecycle: lifecycle,
                onNavigate: setNavigationPath(for:)
            )

        case .savedMatches:
            SavedMatchesListView(matches: matchViewModel.savedMatches) { match in
                matchViewModel.selectMatch(match)
                DispatchQueue.main.async {
                    lifecycle.goToKickoffFirst()
                }
            }

        case .createMatch:
            MatchSettingsListView(matchViewModel: matchViewModel) { viewModel in
                configureMatch(using: viewModel)
                DispatchQueue.main.async {
                    lifecycle.goToKickoffFirst()
                }
            }
        }
    }

    func configureMatch(using viewModel: MatchViewModel) {
        viewModel.configureMatch(
            duration: viewModel.matchDuration,
            periods: viewModel.numberOfPeriods,
            halfTimeLength: viewModel.halfTimeLength,
            hasExtraTime: viewModel.hasExtraTime,
            hasPenalties: viewModel.hasPenalties
        )
    }

    /// Maps lifecycle transitions to navigation updates.
    /// The reducer clears stacked start-flow routes once gameplay begins
    /// and guarantees a clean idle state when a match ends.
    func handleLifecycleNavigation(from oldState: MatchPhase, to newState: MatchPhase) {
        navigationReducer.reduce(path: &navigationPath, from: oldState, to: newState)
    }

}

enum ThemeCardRole {
    case primary
    case secondary
    case positive
    case destructive
}

struct ThemeCardSurfaceStyle {
    let background: Color
    let outline: Color?
    let titleColor: Color
    let subtitleColor: Color
}

func surfaceStyle(for role: ThemeCardRole, theme: AnyTheme) -> ThemeCardSurfaceStyle {
    switch role {
    case .primary:
        return ThemeCardSurfaceStyle(
            background: theme.colors.accentPrimary,
            outline: nil,
            titleColor: theme.colors.textPrimary,
            subtitleColor: theme.colors.textPrimary.opacity(0.8)
        )
    case .secondary:
        return ThemeCardSurfaceStyle(
            background: theme.colors.backgroundElevated,
            outline: theme.colors.outlineMuted,
            titleColor: theme.colors.textPrimary,
            subtitleColor: theme.colors.textSecondary
        )
    case .positive:
        return ThemeCardSurfaceStyle(
            background: theme.colors.matchPositive,
            outline: nil,
            titleColor: theme.colors.textInverted,
            subtitleColor: theme.colors.textInverted.opacity(0.8)
        )
    case .destructive:
        return ThemeCardSurfaceStyle(
            background: theme.colors.matchCritical,
            outline: nil,
            titleColor: theme.colors.textPrimary,
            subtitleColor: theme.colors.textPrimary.opacity(0.84)
        )
    }
}

private struct StartMatchHeroCard: View {
    @Environment(\.theme) private var theme

    var body: some View {
        MenuCard(
            title: "Start",
            subtitle: nil,
            icon: "flag.checkered",
            tint: theme.colors.accentSecondary,
            accessoryIcon: "chevron.forward",
            minHeight: 92,
            role: .primary
        )
    }
}

private struct QuickActionLabel: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color

    var body: some View {
        MenuCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            tint: tint,
            accessoryIcon: "chevron.forward",
            minHeight: 92,
            role: .secondary
        )
    }
}

struct MenuCard: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let accessoryIcon: String?
    let minHeight: CGFloat
    let role: ThemeCardRole

    var body: some View {
        let styling = surfaceStyle(for: role, theme: theme)
        let titleFont = dynamicTitleFont

        ThemeCardContainer(role: role, minHeight: minHeight) {
            HStack(spacing: theme.spacing.s) { // Reduced from theme.spacing.m for more text space
                ZStack {
                    RoundedRectangle(cornerRadius: theme.components.controlCornerRadius, style: .continuous)
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36) // Reduced from 40x40 to give more text space
                    Image(systemName: icon)
                        .font(theme.typography.iconAccent)
                        .foregroundStyle(styling.titleColor)
                }

                VStack(alignment: .leading, spacing: subtitleSpacing) {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(styling.titleColor)
                        .lineLimit(subtitle == nil ? 1 : 2) // Single line when no subtitle, 2 lines when subtitle exists
                        .minimumScaleFactor(subtitle == nil ? 0.55 : 0.65) // More aggressive scaling when no subtitle
                        .layoutPriority(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(theme.typography.cardMeta)
                            .foregroundStyle(styling.subtitleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.60) // Reduced from 0.75 for better subtitle visibility
                    }
                }

                Spacer(minLength: theme.spacing.s)

                if let accessoryIcon {
                    Image(systemName: accessoryIcon)
                        .font(theme.typography.iconSecondary)
                        .foregroundStyle(styling.subtitleColor)
                }
            }
        }
    }

    private var subtitleSpacing: CGFloat {
        subtitle?.isEmpty == false ? theme.spacing.xs : 0
    }

    private var dynamicTitleFont: Font {
        // For cards without subtitles, we can be more generous with title space
        if subtitle == nil {
            // No subtitle, so we can use larger text and allow more scaling
            // Ensure consistent bold weight for all card titles
            return theme.typography.cardHeadline.weight(.semibold)
        } else {
            // Has subtitle, use smaller font for longer titles
            if title.count > 8 {
                return theme.typography.cardMeta.weight(.semibold)
            } else {
                return theme.typography.cardHeadline.weight(.semibold)
            }
        }
    }

    private var iconBackgroundColor: Color {
        switch role {
        case .primary:
            return tint.opacity(0.28)
        case .secondary:
            return tint.opacity(0.22)
        case .positive:
            return tint.opacity(0.16)
        case .destructive:
            return tint.opacity(0.24)
        }
    }
}

struct ThemeCardContainer<Content: View>: View {
    @Environment(\.theme) private var theme

    let role: ThemeCardRole
    let minHeight: CGFloat
    let content: Content

    init(role: ThemeCardRole, minHeight: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.role = role
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        let styling = surfaceStyle(for: role, theme: theme)

        content
            .padding(.vertical, theme.spacing.m)
            .padding(.horizontal, theme.components.cardHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: minHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                    .fill(styling.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                            .stroke(styling.outline ?? .clear, lineWidth: styling.outline == nil ? 0 : 1)
                    )
            )
            .shadow(
                color: Color.black.opacity(theme.components.cardShadowOpacity),
                radius: theme.components.cardShadowRadius,
                x: 0,
                y: theme.components.cardShadowYOffset
            )
            .contentShape(RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous))
    }
}
