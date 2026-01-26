//
//  RefWatchiOSApp.swift
//  RefWatchiOS
//
//  Created by Ibrahim Saidi on 3/9/2025.
//

import Combine
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
  @StateObject private var authController: SupabaseAuthController
  @StateObject private var authCoordinator: AuthenticationCoordinator
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
  @StateObject private var syncController: ConnectivitySyncController
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
    // JSON persistence is no longer used now that Supabase auth is required on iPhone.
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
    let clientProvider = SupabaseClientProvider.shared
    let synchronizer = SupabaseUserProfileSynchronizer(clientProvider: clientProvider)
    let authController = SupabaseAuthController(
      clientProvider: clientProvider,
      profileSynchronizer: synchronizer)
    _authController = StateObject(wrappedValue: authController)
    _authCoordinator = StateObject(wrappedValue: AuthenticationCoordinator(authController: authController))

    let containerResult: (ModelContainer, SwiftDataMatchHistoryStore)
    do {
      containerResult = try ModelContainerFactory.makeStore(
        builder: Self.containerBuilder,
        schema: schema,
        auth: authController)
    } catch {
      fatalError("Failed to create SwiftData container: \(error)")
    }

    let container = containerResult.0
    let swiftHistoryStore = containerResult.1

    let matchRepo = SupabaseMatchHistoryRepository(
      store: swiftHistoryStore,
      authStateProvider: authController,
      api: SupabaseMatchIngestService(),
      backlog: SupabaseMatchSyncBacklogStore(),
      deviceIdProvider: { UIDevice.current.identifierForVendor?.uuidString })
    let historyRepo: MatchHistoryStoring = matchRepo
    let matchSyncController: MatchHistorySyncControlling? = matchRepo

    let jStore: JournalEntryStoring = SupabaseJournalRepository(
      authStateProvider: authController,
      api: SupabaseJournalAPI())

    let swiftScheduleStore = SwiftDataScheduleStore(container: container, auth: authController)
    let schedStore: ScheduleStoring = SupabaseScheduleRepository(
      store: swiftScheduleStore,
      authStateProvider: authController,
      api: SupabaseScheduleAPI(),
      backlog: SupabaseScheduleSyncBacklogStore())

    let swiftTeamStore = SwiftDataTeamLibraryStore(container: container, auth: authController)
    let tStore: TeamLibraryStoring = SupabaseTeamLibraryRepository(
      store: swiftTeamStore,
      authStateProvider: authController,
      api: SupabaseTeamLibraryAPI(),
      backlog: SupabaseTeamSyncBacklogStore())

    let swiftCompetitionStore = SwiftDataCompetitionLibraryStore(container: container, auth: authController)
    let cStore: CompetitionLibraryStoring = SupabaseCompetitionLibraryRepository(
      store: swiftCompetitionStore,
      authStateProvider: authController,
      api: SupabaseCompetitionLibraryAPI(),
      backlog: SupabaseCompetitionSyncBacklogStore())

    let swiftVenueStore = SwiftDataVenueLibraryStore(container: container, auth: authController)
    let vStore: VenueLibraryStoring = SupabaseVenueLibraryRepository(
      store: swiftVenueStore,
      authStateProvider: authController,
      api: SupabaseVenueLibraryAPI(),
      backlog: SupabaseVenueSyncBacklogStore())

    let scheduleUpdater = MatchScheduleStatusUpdater(scheduleStore: schedStore)
    let vm = MatchViewModel(
      history: historyRepo,
      haptics: IOSHaptics(),
      scheduleStatusUpdater: scheduleUpdater)
    let controller = ConnectivitySyncController(
      history: historyRepo,
      auth: authController,
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
    _syncController = StateObject(wrappedValue: controller)
  }

  var body: some Scene {
    WindowGroup {
      self.rootContent
        .environmentObject(self.router)
        .environmentObject(self.syncDiagnostics)
        .environmentObject(self.themeManager)
        .environmentObject(self.authController)
        .environmentObject(self.authCoordinator)
        .environment(\.journalStore, self.journalStore)
        .theme(self.themeManager.theme)
        .task {
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
        .onChange(of: self.scenePhase) { _, phase in
          // Keep WCSession alive while signed in, even when backgrounded.
          // Only stop on explicit sign-out (handled in auth state onChange).
          // This ensures the watch can sync library data and completed matches
          // even when the iOS app is not in the foreground.
          switch phase {
          case .active:
            if self.authController.isSignedIn {
              self.syncController.start()
            } else {
              self.syncController.stop()
            }
          case .inactive, .background:
            // Don't stop - keep session alive for background transfers
            break
          @unknown default:
            break
          }
        }
        .onChange(of: self.authController.state) { _, state in
          switch state {
          case .signedIn:
            if self.scenePhase == .active { self.syncController.start() }
          case .signedOut:
            self.syncController.stop()
          }
          handleAuthStateTransition(to: state)
        }
        .fullScreenCover(item: self.authScreenBinding, content: self.authScreenView)
        .animation(.easeInOut(duration: 0.25), value: self.authController.state)
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
}

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
      SignInView(authController: self.authController)
        .environmentObject(self.authCoordinator)
    case .signUp:
      SignUpView(authController: self.authController)
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
    AppLog.supabase.notice("Performing logout cleanup for local caches")
    let scheduleUpdater = MatchScheduleStatusUpdater(scheduleStore: scheduleStore)
    self.matchVM = MatchViewModel(
      history: self.historyStore,
      haptics: IOSHaptics(),
      scheduleStatusUpdater: scheduleUpdater)
    Task { @MainActor in
      do {
        if let supabaseStore = journalStore as? SupabaseJournalRepository {
          try await supabaseStore.wipeAllForLogout()
        }
      } catch {
        AppLog.supabase
          .error("Failed to wipe journal entries on sign-out: \(error.localizedDescription, privacy: .public)")
      }
    }
  }
}
