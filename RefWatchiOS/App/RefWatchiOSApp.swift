//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import Combine
import ClerkKit
import OSLog
import RefWatchCore
import SwiftData
import SwiftUI
import UIKit

@main
@MainActor
struct RefWatchiOSApp: App {
  @StateObject private var router = AppRouter()
  @StateObject private var themeManager = ThemeManager()
  @StateObject private var authController: ClerkAuthController
  @StateObject private var authCoordinator: AuthenticationCoordinator
  private let repositoryAuthProvider: AnyObject
  // Built once during app init to avoid lazy/self init ordering issues
  private let modelContainer: ModelContainer
  private let historyStore: MatchHistoryStoring
  private let matchSyncController: MatchHistorySyncControlling?
  private let journalStore: JournalEntryStoring
  private let scheduleStore: ScheduleStoring
  private let teamStore: TeamLibraryStoring
  private let competitionStore: CompetitionLibraryStoring
  private let venueStore: VenueLibraryStoring
  @State private var matchVM: MatchViewModel
  private let syncController: ConnectivitySyncController?
  @StateObject private var syncDiagnostics = SyncDiagnosticsCenter()
  @Environment(\.scenePhase) private var scenePhase
  @State private var lastAuthState: AuthState = .signedOut

  // Exposed for tests to override container-building behavior
  static var containerBuilder: ModelContainerBuilding = DefaultModelContainerBuilder()

  init() {
    // Build SwiftData container and store with graceful fallback.
    //
    // Fallback Order (rationale):
    // 1) On-disk SwiftData (preferred): full persistence, query performance, and indexing.
    // 2) In-memory SwiftData: avoids startup crash if persistent container fails while keeping
    //    the app usable.
    // JSON persistence is no longer used now that authenticated cloud sync is required on iPhone.
    let schema = Schema([
      CompletedMatchRecord.self,
      JournalEntryRecord.self,
      // Teams + Library
      TeamRecord.self,
      PlayerRecord.self,
      TeamOfficialRecord.self,
      // Schedule
      ScheduledMatchRecord.self,
      // Competitions
      CompetitionRecord.self,
      // Venues
      VenueRecord.self,
    ])
    let usesInMemoryTestStack =
      TestEnvironment.isRunningUnitTests
      || TestEnvironment.launchesUITestShell

    if usesInMemoryTestStack {
      // ClerkKitUI reads Clerk.shared from SwiftUI's environment in the UI shell.
      // Unit tests never render Clerk UI, so leave the SDK entirely unconfigured there.
      if TestEnvironment.launchesUITestShell {
        Clerk.configure(publishableKey: "pk_test_bW9jay5jbGVyay5hY2NvdW50cy5kZXYk")
      }
      let authController = TestEnvironment.launchesSignedInUITestShell
        ? ClerkAuthController.previewSignedIn(
          userId: "user_ui_test",
          email: "ui-tests@example.com",
          displayName: "UI Tests")
        : ClerkAuthController.previewSignedOut()
      _authController = StateObject(wrappedValue: authController)
      _authCoordinator = StateObject(wrappedValue: AuthenticationCoordinator(authController: authController))
      self.repositoryAuthProvider = authController

      let containerResult: (ModelContainer, SwiftDataMatchHistoryStore)
      do {
        containerResult = try ModelContainerFactory.makeStore(
          builder: Self.containerBuilder,
          schema: schema,
          auth: authController)
      } catch {
        fatalError("Failed to create in-memory SwiftData container for unit tests: \(error)")
      }

      let container = containerResult.0
      let historyRepo: MatchHistoryStoring = containerResult.1
      if TestEnvironment.launchesUITestShell {
        try? historyRepo.wipeAll()
      }
      let journalStore: JournalEntryStoring = InMemoryJournalStore()
      let scheduleStore: ScheduleStoring = InMemoryScheduleStore()
      let teamStore: TeamLibraryStoring = InMemoryTeamLibraryStore()
      let competitionStore: CompetitionLibraryStoring = InMemoryCompetitionLibraryStore()
      let venueStore: VenueLibraryStoring = InMemoryVenueLibraryStore()

      #if DEBUG
        if TestEnvironment.launchesSignedInUITestShell,
           let inMemoryTeamStore = teamStore as? InMemoryTeamLibraryStore
        {
          BackendServiceRegistry.referenceCatalog = UITestReferenceCatalogService()
          _ = try? inMemoryTeamStore.createTeam(
            name: "Metro Library FC",
            shortName: "MLF",
            division: "UI Test")
          _ = try? inMemoryTeamStore.createTeam(
            name: "Rivals Library FC",
            shortName: "RLF",
            division: "UI Test")
        }
      #endif

      let matchViewModel = MatchViewModel(
        history: historyRepo,
        haptics: NoopHaptics(),
        lifecycleHaptics: NoopMatchLifecycleHaptics())

      self.modelContainer = container
      self.historyStore = historyRepo
      self.matchSyncController = nil
      self.journalStore = journalStore
      self.scheduleStore = scheduleStore
      self.teamStore = teamStore
      self.competitionStore = competitionStore
      self.venueStore = venueStore
      _matchVM = State(initialValue: matchViewModel)
      self.syncController = nil
      return
    }

    let environment: BackendEnvironment
    do {
      environment = try BackendEnvironment.load()
    } catch {
      fatalError("Invalid backend configuration: \(error.localizedDescription)")
    }
    Clerk.configure(publishableKey: environment.clerkPublishableKey)
    let authController = ClerkAuthController()
    _authController = StateObject(wrappedValue: authController)
    _authCoordinator = StateObject(wrappedValue: AuthenticationCoordinator(authController: authController))
    let backendClient = BackendAPIClient(baseURL: environment.baseURL, tokenProvider: authController)
    BackendServiceRegistry.client = backendClient
    BackendServiceRegistry.referenceCatalog = BackendReferenceCatalogService(client: backendClient)
    let identityProvider = BackendIdentityProvider(client: backendClient)
    let repositoryAuth = BackendAuthStateProvider(
      clerkStateProvider: authController,
      identityProvider: identityProvider)
    self.repositoryAuthProvider = repositoryAuth

    let containerResult: (ModelContainer, SwiftDataMatchHistoryStore)
    do {
      containerResult = try ModelContainerFactory.makeStore(
        builder: Self.containerBuilder,
        schema: schema,
        auth: repositoryAuth)
    } catch {
      fatalError("Failed to create SwiftData container: \(error)")
    }

    let container = containerResult.0
    let swiftHistoryStore = containerResult.1

    let matchRepo = BackendMatchHistoryRepository(
      store: swiftHistoryStore,
      authStateProvider: repositoryAuth,
      api: BackendMatchRepositoryAPI(client: backendClient),
      backlog: BackendMatchSyncBacklogStore(),
      deviceIdProvider: { UIDevice.current.identifierForVendor?.uuidString })
    let historyRepo: MatchHistoryStoring = matchRepo
    let matchSyncController: MatchHistorySyncControlling? = matchRepo

    let jStore: JournalEntryStoring = BackendJournalRepository(
      authStateProvider: repositoryAuth,
      api: BackendJournalRepositoryAPI(client: backendClient))

    let swiftScheduleStore = SwiftDataScheduleStore(container: container, auth: repositoryAuth)
    let schedStore: ScheduleStoring = BackendScheduleRepository(
      store: swiftScheduleStore,
      authStateProvider: repositoryAuth,
      api: BackendScheduleRepositoryAPI(client: backendClient),
      backlog: BackendScheduleSyncBacklogStore())

    let swiftTeamStore = SwiftDataTeamLibraryStore(container: container, auth: repositoryAuth)
    let tStore: TeamLibraryStoring = BackendTeamLibraryRepository(
      store: swiftTeamStore,
      authStateProvider: repositoryAuth,
      api: BackendTeamRepositoryAPI(client: backendClient),
      backlog: BackendTeamSyncBacklogStore())

    let swiftCompetitionStore = SwiftDataCompetitionLibraryStore(container: container, auth: repositoryAuth)
    let cStore: CompetitionLibraryStoring = BackendCompetitionLibraryRepository(
      store: swiftCompetitionStore,
      authStateProvider: repositoryAuth,
      api: BackendCompetitionRepositoryAPI(client: backendClient),
      backlog: BackendCompetitionSyncBacklogStore())

    let swiftVenueStore = SwiftDataVenueLibraryStore(container: container, auth: repositoryAuth)
    let vStore: VenueLibraryStoring = BackendVenueLibraryRepository(
      store: swiftVenueStore,
      authStateProvider: repositoryAuth,
      api: BackendVenueRepositoryAPI(client: backendClient),
      backlog: BackendVenueSyncBacklogStore())

    let scheduleUpdater = MatchScheduleStatusUpdater(scheduleStore: schedStore)
    let vm = MatchViewModel(
      history: historyRepo,
      haptics: IOSHaptics(),
      lifecycleHaptics: IOSMatchLifecycleHaptics(),
      scheduleStatusUpdater: scheduleUpdater)
    let controller = ConnectivitySyncController(
      history: historyRepo,
      auth: repositoryAuth,
      teamStore: tStore,
      competitionStore: cStore,
      venueStore: vStore,
      scheduleStore: schedStore)

    // Assign to stored properties/wrappers
    self.modelContainer = container
    self.historyStore = historyRepo
    self.matchSyncController = matchSyncController
    self.journalStore = jStore
    self.scheduleStore = schedStore
    self.teamStore = tStore
    self.competitionStore = cStore
    self.venueStore = vStore
    _matchVM = State(initialValue: vm)
    self.syncController = controller
  }

  var body: some Scene {
    WindowGroup {
      if TestEnvironment.isRunningUnitTests {
        Color.clear
          .accessibilityIdentifier("UnitTestHost")
      } else {
        self.liveRootContent
      }
    }
  }

  @ViewBuilder
  private var rootContent: some View {
    switch self.authController.state {
    case .signedIn:
      MainTabView(
        matchViewModel: self.matchVM,
        historyStore: self.historyStore,
        matchSyncController: self.matchSyncController,
        scheduleStore: self.scheduleStore,
        teamStore: self.teamStore,
        competitionStore: self.competitionStore,
        venueStore: self.venueStore,
        authController: self.authController,
        connectivityController: self.syncController)
    case .signedOut:
      SignedOutGateView()
    }
  }

  private var liveRootContent: some View {
    self.rootContent
      .environmentObject(self.router)
      .environmentObject(self.syncDiagnostics)
      .environmentObject(self.themeManager)
      .environmentObject(self.authController)
      .environmentObject(self.authCoordinator)
      .environment(\.journalStore, self.journalStore)
      .theme(self.themeManager.theme)
      .task {
        if TestEnvironment.launchesUITestShell {
          return
        }
        await self.authController.restoreSessionIfAvailable()
        self.authCoordinator.presentWelcomeIfNeeded()
        // One-time healing: if any completed matches reference a schedule still marked scheduled,
        // flip that schedule to completed to keep watch/iOS lists clean.
        Task { @MainActor in
          let completed = (try? self.historyStore.loadAll()) ?? []
          let schedules = self.scheduleStore.loadAll()
          var changed: [ScheduledMatch] = []
          for snapshot in completed {
            if let sid = snapshot.scheduledMatchId, let idx = schedules.firstIndex(where: { $0.id == sid }) {
              var sc = schedules[idx]
              if sc.status == .scheduled { sc.status = .completed; changed.append(sc) }
            }
          }
          for s in changed {
            try? self.scheduleStore.save(s)
          }
        }
      }
      .onReceive(self.router.$authenticationRequest.compactMap { $0 }) { screen in
        self.authCoordinator.activeScreen = screen
        self.router.authenticationRequest = nil
      }
      .onChange(of: self.scenePhase) { phase in
        // Keep WCSession alive while signed in, even when backgrounded.
        // Only stop on explicit sign-out (handled in auth state onChange).
        // This ensures the watch can sync library data and completed matches
        // even when the iOS app is not in the foreground.
        switch phase {
        case .active:
          if self.authController.isSignedIn {
            self.syncController?.start()
          } else {
            self.syncController?.stop()
          }
        case .inactive, .background:
          // Don't stop - keep session alive for background transfers
          break
        @unknown default:
          break
        }
      }
      .onChange(of: self.authController.state) { state in
        switch state {
        case .signedIn:
          if self.scenePhase == .active { self.syncController?.start() }
        case .signedOut:
          self.syncController?.stop()
        }
        handleAuthStateTransition(to: state)
      }
      .fullScreenCover(item: self.authScreenBinding, content: self.authScreenView)
      .animation(.easeInOut(duration: 0.25), value: self.authController.state)
      .environment(Clerk.shared)
  }
}

#if DEBUG
private final class UITestReferenceCatalogService: ReferenceCatalogServing {
  func fetchReferenceTeams(seasonYear: Int) async throws -> [ReferenceTeamOption] {
    guard seasonYear == ReferenceCatalogService.seasonYear else { return [] }
    return ReferenceCatalogService.previewReferenceTeams
  }

  func fetchReferenceCompetitions(seasonYear: Int) async throws -> [ReferenceCompetitionOption] {
    ReferenceCatalogService.fixtureCompetitionRows(seasonYear: seasonYear).map {
      ReferenceCompetitionOption(id: $0.id, code: $0.code, name: $0.name)
    }
  }
}
#endif

extension RefWatchiOSApp {
  private var authScreenBinding: Binding<AuthenticationCoordinator.Screen?> {
    Binding(
      get: { self.authCoordinator.activeScreen },
      set: { self.authCoordinator.activeScreen = $0 })
  }

  @ViewBuilder
  private func authScreenView(_ screen: AuthenticationCoordinator.Screen) -> some View {
    switch screen {
    case .welcome:
      WelcomeView()
        .environmentObject(self.authCoordinator)
    case .signIn:
      SignInView()
        .environmentObject(self.authCoordinator)
    case .signUp:
      SignUpView()
        .environmentObject(self.authCoordinator)
    }
  }
}

extension RefWatchiOSApp {
  private func handleAuthStateTransition(to newState: AuthState) {
    defer { lastAuthState = newState }
    guard case .signedOut = newState else { return }
    if case .signedOut = self.lastAuthState { return }
    self.performLogoutCleanup()
  }

  private func performLogoutCleanup() {
    AppLog.auth.notice("Performing logout cleanup for local caches")
    let scheduleUpdater = MatchScheduleStatusUpdater(scheduleStore: scheduleStore)
    self.matchVM = MatchViewModel(
      history: self.historyStore,
      haptics: IOSHaptics(),
      lifecycleHaptics: IOSMatchLifecycleHaptics(),
      scheduleStatusUpdater: scheduleUpdater)
    Task { @MainActor in
      do {
        if let backendStore = journalStore as? BackendJournalRepository {
          try await backendStore.wipeAllForLogout()
        }
      } catch {
        AppLog.backend
          .error("Failed to wipe journal entries on sign-out: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
