//
//  MatchRootView.swift
//  RefereeAssistant
//
//  Description: Match Mode root surface that restores unfinished sessions,
//  reconciles runtime protection, and routes back to the correct screen.
//

import RefWatchCore
import SwiftData
import SwiftUI

/// Root watch Match Mode view that owns runtime reconciliation and relaunch
/// routing for unfinished matches.
struct MatchRootView: View {
  @Environment(\.theme) private var theme
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment
  @State private var backgroundRuntimeController: BackgroundRuntimeSessionController
  @State private var lifecycleHaptics: WatchMatchLifecycleHaptics
  @State private var matchViewModel: MatchViewModel
  @State private var settingsViewModel: SettingsViewModel
  @State private var lifecycle: MatchLifecycleCoordinator
  @State private var showPersistenceError = false
  @State private var latestSummary: CompletedMatchSummary?
  @State private var hasRestoredPersistedSession = false
  @State private var navigationPath: [MatchRoute] = []
  // Resets the NavigationStack identity when we return to idle to avoid
  // stale column state causing SwiftUI AnyNavigationPath comparison crashes
  @State private var navigationStackID = UUID()
  private let commandHandler: LiveActivityCommandHandler
  private let livePublisher: any MatchLiveActivityPublishing
  private let shouldRestorePersistedSessionOnLaunch: Bool
  private let navigationReducer = MatchNavigationReducer()

  @MainActor
  init(connectivity: ConnectivitySyncProviding? = nil) {
    let activeMatchSessionStore = PersistedActiveMatchSessionStore()
    let runtimeController = BackgroundRuntimeSessionController.makeForCurrentEnvironment()
    let lifecycleHaptics = WatchMatchLifecycleHaptics()
    let matchViewModel = MatchViewModel(
      history: MatchHistoryService(),
      penaltyManager: PenaltyManager(),
      haptics: WatchHaptics(),
      lifecycleHaptics: lifecycleHaptics,
      connectivity: connectivity,
      backgroundRuntimeManager: runtimeController,
      activeMatchSessionStore: activeMatchSessionStore)

    self.init(
      backgroundRuntimeController: runtimeController,
      lifecycleHaptics: lifecycleHaptics,
      matchViewModel: matchViewModel,
      settingsViewModel: SettingsViewModel(),
      lifecycle: MatchLifecycleCoordinator(),
      commandHandler: LiveActivityCommandHandler(),
      livePublisher: LiveActivityStatePublisher(reloadKind: "RefWatchWidgets"),
      shouldRestorePersistedSessionOnLaunch: true)
  }

  @MainActor
  private init(
    backgroundRuntimeController: BackgroundRuntimeSessionController,
    lifecycleHaptics: WatchMatchLifecycleHaptics,
    matchViewModel: MatchViewModel,
    settingsViewModel: SettingsViewModel,
    lifecycle: MatchLifecycleCoordinator,
    commandHandler: LiveActivityCommandHandler,
    livePublisher: any MatchLiveActivityPublishing,
    shouldRestorePersistedSessionOnLaunch: Bool)
  {
    _backgroundRuntimeController = State(initialValue: backgroundRuntimeController)
    _lifecycleHaptics = State(initialValue: lifecycleHaptics)
    _matchViewModel = State(initialValue: matchViewModel)
    _settingsViewModel = State(initialValue: settingsViewModel)
    _lifecycle = State(initialValue: lifecycle)
    self.commandHandler = commandHandler
    self.livePublisher = livePublisher
    self.shouldRestorePersistedSessionOnLaunch = shouldRestorePersistedSessionOnLaunch
  }

#if DEBUG
  @MainActor
  init(previewConfiguration: MatchRootPreviewConfiguration) {
    self.init(
      backgroundRuntimeController: previewConfiguration.backgroundRuntimeController,
      lifecycleHaptics: previewConfiguration.lifecycleHaptics,
      matchViewModel: previewConfiguration.matchViewModel,
      settingsViewModel: previewConfiguration.settingsViewModel,
      lifecycle: previewConfiguration.lifecycle,
      commandHandler: previewConfiguration.commandHandler,
      livePublisher: previewConfiguration.livePublisher,
      shouldRestorePersistedSessionOnLaunch: false)
  }
#endif

  var body: some View {
    ZStack {
      NavigationStack(path: self.$navigationPath) {
        Group {
          switch self.lifecycle.state {
          case .idle:
            List {
              heroSection
              quickActionsSection
            }
            .listStyle(.carousel)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .scenePadding(.horizontal)
            .padding(.vertical, self.theme.components.listVerticalSpacing)
            .background(self.theme.colors.backgroundPrimary)
          case .kickoffFirstHalf:
            MatchKickOffView(
              matchViewModel: self.matchViewModel,
              lifecycle: self.lifecycle)
          case .setup:
            MatchSetupView(
              matchViewModel: self.matchViewModel,
              lifecycle: self.lifecycle,
              isLifecycleAlertPresented: self.lifecycleHaptics.activeAlert != nil,
              liveActivityPublisher: self.livePublisher,
              commandHandler: self.commandHandler)
          case .kickoffSecondHalf:
            MatchKickOffView(
              matchViewModel: self.matchViewModel,
              isSecondHalf: true,
              defaultSelectedTeam: (self.matchViewModel.getSecondHalfKickingTeam() == .home) ? .home : .away,
              lifecycle: self.lifecycle)
          case .kickoffExtraTimeFirstHalf:
            MatchKickOffView(
              matchViewModel: self.matchViewModel,
              extraTimePhase: 1,
              lifecycle: self.lifecycle)
          case .kickoffExtraTimeSecondHalf:
            MatchKickOffView(
              matchViewModel: self.matchViewModel,
              extraTimePhase: 2,
              defaultSelectedTeam: (self.matchViewModel.getETSecondHalfKickingTeam() == .home) ? .home : .away,
              lifecycle: self.lifecycle)
          case .countdown:
            // Show countdown view with context from lifecycle coordinator
            if let kickoffType = lifecycle.pendingKickoffType,
               let kickingTeam = lifecycle.pendingKickingTeam
            {
              CountdownView(
                matchViewModel: self.matchViewModel,
                lifecycle: self.lifecycle,
                kickoffType: kickoffType,
                kickingTeam: kickingTeam)
            } else {
              // Fallback: if context is missing, go back to idle
              Text("Error: Missing countdown context")
                .onAppear {
                  self.lifecycle.resetToStart()
                }
            }
          case .choosePenaltyFirstKicker:
            PenaltyFirstKickerView(
              matchViewModel: self.matchViewModel,
              lifecycle: self.lifecycle)
          case .penalties:
            PenaltyShootoutView(
              matchViewModel: self.matchViewModel,
              lifecycle: self.lifecycle)
          case .finished:
            FullTimeView(
              matchViewModel: self.matchViewModel,
              lifecycle: self.lifecycle)
          }
        }
        .navigationDestination(for: MatchRoute.self) { route in
          destination(for: route)
        }
      }
      .allowsHitTesting(self.lifecycleHaptics.activeAlert == nil)
      .accessibilityHidden(self.lifecycleHaptics.activeAlert != nil)

      if let alert = self.lifecycleHaptics.activeAlert {
        LifecycleAlertOverlayView(alert: alert) {
          self.lifecycleHaptics.acknowledgeCurrentAlert()
        }
        .transition(.opacity)
      }
    }
    // Recreate the stack whenever we reset to idle to clear any lingering
    // navigation column state from the previous match session.
    .id(self.navigationStackID)
    .animation(.easeInOut(duration: 0.2), value: self.lifecycleHaptics.activeAlert?.id)
    .environment(self.settingsViewModel)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .task {
      guard self.shouldRestorePersistedSessionOnLaunch, self.hasRestoredPersistedSession == false else { return }
      self.hasRestoredPersistedSession = true
      if self.matchViewModel.restorePersistedActiveMatchSessionIfAvailable() {
        self.resumeUnfinishedMatchIfNeeded()
      }
    }
    .task {
      self.latestSummary = self.matchViewModel.latestCompletedMatchSummary()
    }
    .task {
      self.matchViewModel.updateLibrary(with: self.aggregateEnvironment.librarySnapshot)
    }
    .onReceive(self.aggregateEnvironment.$librarySnapshot) { snapshot in
      self.matchViewModel.updateLibrary(with: snapshot)
    }
    .onChange(of: self.scenePhase) { _, newPhase in
      MatchAlertInvestigationLogger.timestamped(
        "matchRoot.scenePhase newPhase=\(self.debugScenePhaseName(newPhase)) lifecycleState=\(String(describing: self.lifecycle.state)) runtimeStatus=\(self.debugRuntimeStatusName(self.backgroundRuntimeController.status)) hasActiveAlert=\(self.lifecycleHaptics.activeAlert != nil) waitingForHalfTimeStart=\(self.matchViewModel.waitingForHalfTimeStart) pendingPeriodBoundaryDecision=\(self.matchViewModel.pendingPeriodBoundaryDecision?.rawValue ?? "none") isPaused=\(self.matchViewModel.isPaused) isMatchInProgress=\(self.matchViewModel.isMatchInProgress)")
      switch newPhase {
      case .active:
        self.matchViewModel.reconcileBackgroundRuntimeSession()
        self.resumeUnfinishedMatchIfNeeded()
      case .inactive:
        self.lifecycleHaptics.cancelPendingPlayback()
        self.matchViewModel.reconcileBackgroundRuntimeSession()
      case .background:
        self.lifecycleHaptics.cancelPendingPlayback()
        #if DEBUG
        print("[MatchRootView] scene phase → background (cannot start sessions)")
        #endif
      @unknown default:
        break
      }
    }
    .onChange(of: self.lifecycleHaptics.activeAlert?.id) { oldValue, newValue in
      MatchAlertInvestigationLogger.timestamped(
        "matchRoot.activeAlert old=\(oldValue?.uuidString ?? "none") new=\(newValue?.uuidString ?? "none") cue=\(self.lifecycleHaptics.activeAlert?.cue.debugName ?? "none") scenePhase=\(self.debugScenePhaseName(self.scenePhase)) lifecycleState=\(String(describing: self.lifecycle.state)) runtimeStatus=\(self.debugRuntimeStatusName(self.backgroundRuntimeController.status))")
    }
    .onChange(of: self.backgroundRuntimeController.status) { oldValue, newValue in
      MatchAlertInvestigationLogger.timestamped(
        "matchRoot.runtimeStatus old=\(self.debugRuntimeStatusName(oldValue)) new=\(self.debugRuntimeStatusName(newValue)) scenePhase=\(self.debugScenePhaseName(self.scenePhase)) hasActiveAlert=\(self.lifecycleHaptics.activeAlert != nil)")
    }
    .onOpenURL { url in
      // Deep link from Smart Stack widget
      guard url.scheme == "refwatch" else { return }
      if url.host == "timer" {
        if self.hasUnfinishedMatch {
          self.resumeUnfinishedMatchIfNeeded()
        } else {
          setNavigationPath(for: .startFlow)
        }
        consumeWidgetCommand()
      }
    }
    .onChange(of: self.matchViewModel.matchCompleted) { completed, _ in
      #if DEBUG
      print("DEBUG: MatchRootView.onChange matchCompleted=\(completed) state=\(self.lifecycle.state)")
      #endif
      // Defensive fallback to guarantee return to idle after finalize
      if completed, self.lifecycle.state != .idle {
        self.lifecycle.resetToStart()
        self.matchViewModel.resetMatch()
      }
      if completed {
        self.latestSummary = self.matchViewModel.latestCompletedMatchSummary()
      }
    }
    .onChange(of: self.matchViewModel.pendingPeriodBoundaryDecision?.rawValue) { _, _ in
      self.resumeUnfinishedMatchIfNeeded()
    }
    .onChange(of: self.lifecycle.state) { oldState, newState in
      #if DEBUG
      print("DEBUG: MatchRootView lifecycle transition: \(oldState) → \(newState)")
      print("DEBUG: Navigation path before: \(self.navigationPath)")
      #endif

      handleLifecycleNavigation(from: oldState, to: newState)

      if newState == .idle, oldState != .idle {
        // Fresh stack prevents SwiftUI from comparing path elements of
        // mismatched types after a completed match.
        self.navigationStackID = UUID()
      }

      #if DEBUG
      print("DEBUG: Navigation path after: \(self.navigationPath)")
      #endif

    }
    .onChange(of: self.matchViewModel.lastPersistenceError) { newValue, _ in
      if newValue != nil { self.showPersistenceError = true }
    }
    .alert("Save Failed", isPresented: self.$showPersistenceError) {
      Button("OK") { self.matchViewModel.lastPersistenceError = nil }
    } message: {
      Text(self.matchViewModel.lastPersistenceError ?? "An unknown error occurred while saving.")
    }
  }
}

private extension MatchRootView {
  func debugScenePhaseName(_ phase: ScenePhase) -> String {
    switch phase {
    case .active:
      "active"
    case .inactive:
      "inactive"
    case .background:
      "background"
    @unknown default:
      "unknown"
    }
  }

  func debugRuntimeStatusName(_ status: BackgroundRuntimeSessionController.Status) -> String {
    switch status {
    case .idle:
      "idle"
    case .recovering:
      "recovering"
    case .authorizing:
      "authorizing"
    case .starting:
      "starting"
    case let .running(startedAt):
      "running(startedAt:\(startedAt.timeIntervalSince1970))"
    case .stopping:
      "stopping"
    case .failed:
      "failed"
    }
  }
}

// MARK: - Preview

#if DEBUG
#Preview("Match Root - Idle") {
  MatchRootView(previewConfiguration: .idle())
    .environmentObject(WatchPreviewSupport.makeAggregateEnvironment())
    .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.root.idle"))
    .watchPreviewChrome()
}

#Preview("Match Root - End of Half") {
  MatchRootView(previewConfiguration: .endOfHalfAlertVisible())
    .environmentObject(WatchPreviewSupport.makeAggregateEnvironment())
    .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.root.boundary"))
    .watchPreviewChrome()
}

#Preview("Match Root - Half-Time Over") {
  MatchRootView(previewConfiguration: .halfTimeOverAlertVisible())
    .environmentObject(WatchPreviewSupport.makeAggregateEnvironment())
    .defaultAppStorage(WatchPreviewSupport.makeDefaults(suiteName: "RefWatch.watchPreview.root.halftime"))
    .watchPreviewChrome()
}
#endif

extension MatchRootView {
  @ViewBuilder
  private var heroSection: some View {
    Section {
      Button {
        self.setNavigationPath(for: .startFlow)
      } label: {
        StartMatchHeroCard()
      }
      .accessibilityIdentifier("startRow")
      .buttonStyle(.plain)
      .listRowInsets(self.quickActionInsets)
      .listRowBackground(Color.clear)
    }
  }

  @ViewBuilder
  private var quickActionsSection: some View {
    Section {
      NavigationLink {
        MatchHistoryView(matchViewModel: self.matchViewModel)
      } label: {
        QuickActionLabel(
          title: "History",
          icon: "clock.arrow.circlepath")
      }
      .accessibilityIdentifier("historyRow")
      .buttonStyle(.plain)
      .listRowInsets(self.quickActionInsets)
      .listRowBackground(Color.clear)

      NavigationLink {
        SettingsScreen(settingsViewModel: self.settingsViewModel)
      } label: {
        QuickActionLabel(
          title: "Settings",
          icon: "gear")
      }
      .accessibilityIdentifier("settingsRow")
      .buttonStyle(.plain)
      .listRowInsets(self.quickActionInsets)
      .listRowBackground(Color.clear)
    }
  }

  private func consumeWidgetCommand() {
    guard self.commandHandler.processPendingCommand(model: self.matchViewModel) != nil else { return }
    self.livePublisher.publish(for: self.matchViewModel)
  }

  private var quickActionInsets: EdgeInsets {
    let vertical = self.theme.components.listRowVerticalInset
    let horizontal = self.theme.components.cardHorizontalPadding
    return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
  }

  private var hasUnfinishedMatch: Bool {
    self.matchViewModel.currentMatch != nil && self.matchViewModel.matchCompleted == false
  }

  /// Routes the UI back to the correct Match Mode screen after restoring an
  /// unfinished match snapshot or recovering an active workout session.
  private func resumeUnfinishedMatchIfNeeded() {
    guard self.hasUnfinishedMatch else { return }
    self.lifecycle.routeToResumedState(using: self.matchViewModel)
  }

  private func setNavigationPath(for route: MatchRoute) {
    self.navigationPath = route.canonicalPath
  }

  @ViewBuilder
  private func destination(for route: MatchRoute) -> some View {
    switch route {
    case .startFlow:
      StartMatchScreen(
        matchViewModel: self.matchViewModel,
        lifecycle: self.lifecycle,
        onNavigate: self.setNavigationPath(for:))

    case .savedMatches:
      SavedMatchesListView(matches: self.matchViewModel.savedMatches) { match in
        self.matchViewModel.selectMatch(match)
        DispatchQueue.main.async {
          self.lifecycle.goToKickoffFirst()
        }
      }

    case .createMatch:
      MatchSettingsListView(matchViewModel: self.matchViewModel) { viewModel in
        self.configureMatch(using: viewModel)
        DispatchQueue.main.async {
          self.lifecycle.goToKickoffFirst()
        }
      }
    }
  }

  private func configureMatch(using viewModel: MatchViewModel) {
    viewModel.configureMatch(
      duration: viewModel.matchDuration,
      periods: viewModel.numberOfPeriods,
      halfTimeLength: viewModel.halfTimeLength,
      hasExtraTime: viewModel.hasExtraTime,
      hasPenalties: viewModel.hasPenalties)
  }

  /// Maps lifecycle transitions to navigation updates.
  /// The reducer clears stacked start-flow routes once gameplay begins
  /// and guarantees a clean idle state when a match ends.
  private func handleLifecycleNavigation(from oldState: MatchPhase, to newState: MatchPhase) {
    self.navigationReducer.reduce(path: &self.navigationPath, from: oldState, to: newState)
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
    ThemeCardSurfaceStyle(
      background: theme.colors.accentPrimary,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.8))
  case .secondary:
    ThemeCardSurfaceStyle(
      background: theme.colors.backgroundElevated,
      outline: theme.colors.outlineMuted,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textSecondary)
  case .positive:
    ThemeCardSurfaceStyle(
      background: theme.colors.matchPositive,
      outline: nil,
      titleColor: theme.colors.textInverted,
      subtitleColor: theme.colors.textInverted.opacity(0.8))
  case .destructive:
    ThemeCardSurfaceStyle(
      background: theme.colors.matchCritical,
      outline: nil,
      titleColor: theme.colors.textPrimary,
      subtitleColor: theme.colors.textPrimary.opacity(0.84))
  }
}

private struct StartMatchHeroCard: View {
  @Environment(\.theme) private var theme

  var body: some View {
    // Styled to match SettingsNavigationRow sizing and typography for consistency
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: self.theme.spacing.m) {
        Image(systemName: "flag.checkered")
          .font(.title2)
          .foregroundStyle(self.theme.colors.accentSecondary)

        Text("Start")
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
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
      HStack(spacing: self.theme.spacing.m) {
        Image(systemName: self.icon)
          .font(.title2)
          .foregroundStyle(self.theme.colors.accentSecondary)

        Text(self.title)
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
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

    self.content
      .padding(.vertical, self.theme.spacing.m)
      .padding(.horizontal, self.theme.components.cardHorizontalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(minHeight: self.minHeight, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
          .fill(styling.background)
          .overlay(
            RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
              .stroke(styling.outline ?? .clear, lineWidth: styling.outline == nil ? 0 : 1)))
      .shadow(
        color: Color.black.opacity(self.theme.components.cardShadowOpacity),
        radius: self.theme.components.cardShadowRadius,
        x: 0,
        y: self.theme.components.cardShadowYOffset)
      .contentShape(RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous))
  }
}
