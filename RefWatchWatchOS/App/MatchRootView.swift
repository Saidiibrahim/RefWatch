//
//  MatchRootView.swift
//  RefereeAssistant
//
//  Description: The Match mode home with quick actions and lifecycle routing.
//

import Combine
import RefWatchCore
import SwiftData
import SwiftUI

struct MatchRootView: View {
  @Environment(\.theme) private var theme
  @EnvironmentObject private var appModeController: AppModeController
  @EnvironmentObject private var aggregateEnvironment: AggregateSyncEnvironment
  @Environment(\.modeSwitcherPresentation) private var modeSwitcherPresentation
  @Environment(\.modeSwitcherBlockReason) private var modeSwitcherBlockReason
  @State private var backgroundRuntimeController: BackgroundRuntimeSessionController
  @State private var matchViewModel: MatchViewModel
  @State private var settingsViewModel: SettingsViewModel
  @State private var lifecycle: MatchLifecycleCoordinator
  @State private var showPersistenceError = false
  @State private var latestSummary: CompletedMatchSummary?
  @State private var navigationPath: [MatchRoute] = []
  // Resets the NavigationStack identity when we return to idle to avoid
  // stale column state causing SwiftUI AnyNavigationPath comparison crashes
  @State private var navigationStackID = UUID()
  private let commandHandler = LiveActivityCommandHandler()
  private let livePublisher = LiveActivityStatePublisher(reloadKind: "RefWatchWidgets")
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
        connectivity: connectivity))
    }
    _settingsViewModel = State(initialValue: SettingsViewModel())
    _lifecycle = State(initialValue: MatchLifecycleCoordinator())
  }

  var body: some View {
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
            lifecycle: self.lifecycle)
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
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            self.modeSwitcherPresentation.wrappedValue = true
          } label: {
            Image(systemName: "chevron.backward")
          }
          .labelStyle(.iconOnly)
          .opacity(isModeSwitcherBlocked ? 0.55 : 1)
          .accessibilityIdentifier("matchModeSwitcherButton")
        }
      }
      .navigationDestination(for: MatchRoute.self) { route in
        destination(for: route)
      }
    }
    // Recreate the stack whenever we reset to idle to clear any lingering
    // navigation column state from the previous match session.
    .id(self.navigationStackID)
    .environment(self.settingsViewModel)
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
    .task {
      self.latestSummary = self.matchViewModel.latestCompletedMatchSummary()
    }
    .task {
      self.matchViewModel.updateLibrary(with: self.aggregateEnvironment.librarySnapshot)
    }
    .onAppear {
      updateModeSwitcherBlock()
    }
    .onReceive(self.aggregateEnvironment.$librarySnapshot) { snapshot in
      self.matchViewModel.updateLibrary(with: snapshot)
    }
    .onOpenURL { url in
      // Deep link from Smart Stack widget
      guard url.scheme == "refzone" else { return }
      if url.host == "timer" {
        // Route into the Timer surface when a match is active; otherwise land on start
        if self.matchViewModel.isMatchInProgress ||
          self.matchViewModel.isHalfTime ||
          self.matchViewModel.penaltyShootoutActive
        {
          self.lifecycle.goToSetup() // MatchSetupView hosts TimerView in the middle tab
        } else if self.matchViewModel.waitingForSecondHalfStart {
          self.lifecycle.goToKickoffSecond()
        } else if self.matchViewModel.waitingForET1Start {
          self.lifecycle.goToKickoffETFirst()
        } else if self.matchViewModel.waitingForET2Start {
          self.lifecycle.goToKickoffETSecond()
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

      if newState != .idle {
        self.appModeController.overrideForActiveSession(.match)
      }

      updateModeSwitcherBlock()
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
    let aggregateEnvironment = self.makeAggregateSyncEnvironment()

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
      AggregateSyncStatusRecord.self,
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
      deltaStore: deltaStore)

    // Create connectivity client (with nil session for preview)
    let connectivity = WatchConnectivitySyncClient(
      session: nil,
      aggregateCoordinator: coordinator)

    // Create and return the environment
    return AggregateSyncEnvironment(
      libraryStore: libraryStore,
      chunkStore: chunkStore,
      deltaStore: deltaStore,
      coordinator: coordinator,
      connectivity: connectivity)
  }
}

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

  private func setNavigationPath(for route: MatchRoute) {
    self.navigationPath = route.canonicalPath
  }

  private var isModeSwitcherBlocked: Bool {
    self.lifecycle.state != .idle
  }

  private func updateModeSwitcherBlock() {
    if self.isModeSwitcherBlocked {
      self.modeSwitcherBlockReason.wrappedValue = .activeMatch
    } else if self.modeSwitcherBlockReason.wrappedValue == .activeMatch {
      self.modeSwitcherBlockReason.wrappedValue = nil
    }
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
