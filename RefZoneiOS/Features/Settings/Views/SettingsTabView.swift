//
//  SettingsTabView.swift
//  RefWatchiOS
//
//  Placeholder for app settings & sync controls
//

import SwiftUI
import RefWatchCore
import Clerk

struct SettingsTabView: View {
    let historyStore: MatchHistoryStoring
    @EnvironmentObject private var syncDiagnostics: SyncDiagnosticsCenter
    @Environment(\.clerk) private var clerk
    @State private var defaultPeriod: Int = 45
    @State private var extraTime: Bool = false
    @State private var penaltyRounds: Int = 5
    @State private var showingInfoAlert = false
    @State private var infoMessage: String = ""
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if clerk.user != nil {
                        HStack(spacing: 12) {
                            UserButton()
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading) {
                                Text(clerk.user?.firstName ?? clerk.user?.username ?? "Signed in")
                                    .font(.headline)
                                Text("Manage your profile or sign out")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Manage") { activeSheet = .profile }
                                .buttonStyle(.bordered)
                        }
                        Text("Signing out keeps local data. New history will not be tagged with your account.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button { activeSheet = .auth } label: {
                            Label("Sign in", systemImage: "person.crop.circle.badge.plus")
                        }
                        Text("Sign in on iPhone to tag new match history to your account. You can continue offline without signing in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Library") {
                    NavigationLink {
                        LibrarySettingsView()
                    } label: {
                        Label("View Library", systemImage: "books.vertical")
                    }
                }
                if syncDiagnostics.showBanner, let msg = syncDiagnostics.lastErrorMessage {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sync Issue Detected").font(.headline)
                                Text(msg).font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let ctx = syncDiagnostics.lastErrorContext {
                                    Text(ctx).font(.caption2).foregroundStyle(.secondary)
                                }
                                Button("Dismiss") { syncDiagnostics.dismiss() }
                                    .buttonStyle(.bordered)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section("Defaults") {
                    Stepper(value: $defaultPeriod, in: 30...60, step: 5) {
                        LabeledContent("Regulation Period", value: "\(defaultPeriod) min")
                    }
                    Toggle("Extra Time Enabled", isOn: $extraTime)
                    Stepper(value: $penaltyRounds, in: 3...10) {
                        LabeledContent("Penalty Rounds", value: "\(penaltyRounds)")
                    }
                }

                Section("Sync") {
                    LabeledContent("Watch", value: "Connected • Placeholder")
                    Button { } label: { Label("Resync Now", systemImage: "arrow.clockwise") }
                }

                Section("Data") {
                    Button(role: .destructive) { wipeHistory() } label: { Label("Wipe Local Data", systemImage: "trash") }
                }

                #if DEBUG
                Section("Debug") {
                    Button { seedDemoHistory() } label: { Label("Seed Demo History", systemImage: "sparkles") }
                    Button { seedDemoSchedule() } label: { Label("Seed Demo Schedule", systemImage: "calendar.badge.plus") }
                }
                #endif
            }
            .navigationTitle("Settings")
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .auth:
                    AuthView()
                        .presentationDetents([.large])
                case .profile:
                    UserProfileView()
                        .presentationDetents([.large])
                }
            }
            // Dismiss any presented clerk UI when auth state changes
            .onChange(of: clerk.user?.id) { _ in
                activeSheet = nil
            }
            .alert("Info", isPresented: $showingInfoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(infoMessage)
            }
        }
    }
}

private extension SettingsTabView {
    enum ActiveSheet: Identifiable { case auth, profile
        var id: String { self == .auth ? "auth" : "profile" }
    }

    func wipeHistory() {
        do {
            try historyStore.wipeAll()
            let schedule = ScheduleService()
            schedule.wipeAll()
            infoMessage = "Local match history wiped."
            showingInfoAlert = true
        } catch {
            infoMessage = "Failed to wipe data: \(error.localizedDescription)"
            showingInfoAlert = true
        }
    }

    func seedDemoHistory() {
        let samples: [(String, String, Int, Int)] = [
            ("Leeds United", "Newcastle United", 2, 1),
            ("Arsenal", "Chelsea", 1, 1),
            ("Barcelona", "Real Madrid", 3, 2),
            ("Bayern", "Dortmund", 0, 0),
            ("Inter", "Milan", 4, 3)
        ]
        var saved = 0
        for s in samples {
            let m = Match(homeTeam: s.0, awayTeam: s.1)
            var final = m
            final.homeScore = s.2
            final.awayScore = s.3
            let snapshot = CompletedMatch(match: final, events: [])
            do { try historyStore.save(snapshot); saved += 1 } catch { }
        }
        infoMessage = "Seeded \(saved) demo matches."
        showingInfoAlert = true
    }

    func seedDemoSchedule() {
        let store = ScheduleService()
        store.wipeAll()
        let cal = Calendar.current
        let now = Date()
        let today10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
        let tomorrow12 = cal.date(byAdding: .day, value: 1, to: cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now) ?? now
        let saturday14 = cal.nextDate(after: now, matching: DateComponents(hour: 14, weekday: 7), matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        let items = [
            ScheduledMatch(homeTeam: "U16 Boys", awayTeam: "Rivals", kickoff: today10),
            ScheduledMatch(homeTeam: "U18 Girls", awayTeam: "City", kickoff: tomorrow12),
            ScheduledMatch(homeTeam: "U14 Boys", awayTeam: "United", kickoff: saturday14),
        ]
        items.forEach { store.save($0) }
        infoMessage = "Seeded demo schedule (Today + Upcoming)."
        showingInfoAlert = true
    }
}

#Preview {
    SettingsTabView(historyStore: MatchHistoryService())
        .environmentObject(SyncDiagnosticsCenter())
}
