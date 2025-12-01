//
//  MatchRootView.swift
//  RefereeAssistant
//
//  Description: The Match mode home with quick actions and lifecycle routing.
//

import SwiftUI
import SwiftData
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
                case .countdown:
                    // Show countdown view with context from lifecycle coordinator
                    if let kickoffType = lifecycle.pendingKickoffType,
                       let kickingTeam = lifecycle.pendingKickingTeam {
                        CountdownView(
                            matchViewModel: matchViewModel,
                            lifecycle: lifecycle,
                            kickoffType: kickoffType,
                            kickingTeam: kickingTeam
                        )
                    } else {
                        // Fallback: if context is missing, go back to idle
                        Text("Error: Missing countdown context")
                            .onAppear {
                                lifecycle.resetToStart()
                            }
                    }
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

// MARK: - Preview
#Preview("Match Root - Idle") {
    // Create preview dependencies
    MatchRootView_PreviewProvider.makePreview()
}

// MARK: - Preview Provider
/// Helper to build preview dependencies for MatchRootView
@MainActor
private struct MatchRootView_PreviewProvider {
    static func makePreview() -> some View {
        let appModeController = AppModeController()
        let mockTheme = AnyTheme(theme: DefaultTheme())
        let aggregateEnvironment = makeAggregateSyncEnvironment()
        
        return MatchRootView()
            .environmentObject(appModeController)
            .environmentObject(aggregateEnvironment)
            .environment(\.theme, mockTheme)
            .environment(\.modeSwitcherPresentation, .constant(false))
    }
    
    /// Creates an in-memory AggregateSyncEnvironment for preview
    static func makeAggregateSyncEnvironment() -> AggregateSyncEnvironment {
        // Create an in-memory ModelContainer for SwiftData
        let schema = Schema([
            AggregateTeamRecord.self,
            AggregatePlayerRecord.self,
            AggregateTeamOfficialRecord.self,
            AggregateCompetitionRecord.self,
            AggregateVenueRecord.self,
            AggregateScheduleRecord.self,
            AggregateHistoryRecord.self,
            AggregateSnapshotChunkRecord.self,
            AggregateDeltaRecord.self,
            AggregateSyncStatusRecord.self
        ])
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            fatalError("Could not create ModelContainer for preview")
        }
        
        // Create stores with the in-memory container
        let libraryStore = WatchAggregateLibraryStore(container: container)
        let chunkStore = WatchAggregateSnapshotChunkStore(container: container)
        let deltaStore = WatchAggregateDeltaOutboxStore(container: container)
        
        // Create coordinator
        let coordinator = WatchAggregateSyncCoordinator(
            libraryStore: libraryStore,
            chunkStore: chunkStore,
            deltaStore: deltaStore
        )
        
        // Create connectivity client (with nil session for preview)
        let connectivity = WatchConnectivitySyncClient(
            session: nil,
            aggregateCoordinator: coordinator
        )
        
        // Create and return the environment
        return AggregateSyncEnvironment(
            libraryStore: libraryStore,
            chunkStore: chunkStore,
            deltaStore: deltaStore,
            coordinator: coordinator,
            connectivity: connectivity
        )
    }
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
            .accessibilityIdentifier("startRow")
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
                    icon: "clock.arrow.circlepath"
                )
            }
            .accessibilityIdentifier("historyRow")
            .buttonStyle(.plain)
            .listRowInsets(quickActionInsets)
            .listRowBackground(Color.clear)

            NavigationLink {
                SettingsScreen(settingsViewModel: settingsViewModel)
            } label: {
                QuickActionLabel(
                    title: "Settings",
                    icon: "gear"
                )
            }
            .accessibilityIdentifier("settingsRow")
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
        // Styled to match SettingsNavigationRow sizing and typography for consistency
        ThemeCardContainer(role: .secondary, minHeight: 72) {
            HStack(spacing: theme.spacing.m) {
                Image(systemName: "flag.checkered")
                    .font(.title2)
                    .foregroundStyle(theme.colors.accentSecondary)

                Text("Start")
                    .font(theme.typography.cardHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                Spacer()
            }
        }
    }
}

private struct QuickActionLabel: View {
    @Environment(\.theme) private var theme

    let title: String
    let icon: String

    var body: some View {
        // Reuse SettingsNavigationRow visual language for quick actions
        ThemeCardContainer(role: .secondary, minHeight: 72) {
            HStack(spacing: theme.spacing.m) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(theme.colors.accentSecondary)

                Text(title)
                    .font(theme.typography.cardHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                // Spacer removed - Text frame(maxWidth: .infinity) handles layout,
                // and NavigationLink provides its own chevron spacing
            }
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
