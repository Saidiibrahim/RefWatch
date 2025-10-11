//
//  MatchSetupView.swift
//  RefZoneiOS
//
//  iOS setup form for creating and starting a match using RefWatchCore.
//  Skeleton only — navigation is delegated via optional onStarted closure.
//

import SwiftUI
import RefWatchCore

struct MatchSetupView: View {
    let matchViewModel: MatchViewModel
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring
    let venueStore: VenueLibraryStoring
    var onStarted: ((MatchViewModel) -> Void)? = nil

    // Basic inputs (sensible defaults)
    @State private var homeTeam: String = "Home"
    @State private var awayTeam: String = "Away"
    @State private var selectedHomeTeam: TeamRecord?
    @State private var selectedAwayTeam: TeamRecord?
    @State private var useCustomHomeTeam: Bool = true
    @State private var useCustomAwayTeam: Bool = true
    @State private var showingHomeTeamPicker = false
    @State private var showingAwayTeamPicker = false
    @State private var selectedCompetition: CompetitionRecord?
    @State private var selectedVenue: VenueRecord?
    @State private var showingCompetitionPicker = false
    @State private var showingVenuePicker = false
    @State private var durationMinutes: Int = 90
    @State private var halfTimeMinutes: Int = 15
    @State private var hasExtraTime: Bool = false
    @State private var etHalfMinutes: Int = 15
    @State private var hasPenalties: Bool = false
    @State private var penaltyRounds: Int = 5

    @State private var validationMessage: String?
    @State private var showKickoffFirstHalf: Bool = false

    init(
        matchViewModel: MatchViewModel,
        teamStore: TeamLibraryStoring,
        competitionStore: CompetitionLibraryStoring,
        venueStore: VenueLibraryStoring,
        onStarted: ((MatchViewModel) -> Void)? = nil,
        prefillTeams: (String, String)? = nil
    ) {
        self.matchViewModel = matchViewModel
        self.teamStore = teamStore
        self.competitionStore = competitionStore
        self.venueStore = venueStore
        self.onStarted = onStarted
        if let teams = prefillTeams {
            _homeTeam = State(initialValue: teams.0)
            _awayTeam = State(initialValue: teams.1)
        }
    }

    @EnvironmentObject private var authController: SupabaseAuthController

    var body: some View {
        Group {
            if authController.isSignedIn {
                formContent
            } else {
                SignedOutFeaturePlaceholder(
                    description: "Sign in to configure and start new matches on your iPhone."
                )
            }
        }
        .navigationTitle("Match Setup")
        .sheet(isPresented: $showingHomeTeamPicker) {
            TeamPickerSheet(teamStore: teamStore) { team in
                selectedHomeTeam = team
                homeTeam = team.name
                useCustomHomeTeam = false
                validate()
            }
        }
        .sheet(isPresented: $showingAwayTeamPicker) {
            TeamPickerSheet(teamStore: teamStore) { team in
                selectedAwayTeam = team
                awayTeam = team.name
                useCustomAwayTeam = false
                validate()
            }
        }
        .sheet(isPresented: $showingCompetitionPicker) {
            CompetitionPickerSheet(competitionStore: competitionStore) { competition in
                selectedCompetition = competition
            }
        }
        .sheet(isPresented: $showingVenuePicker) {
            VenuePickerSheet(venueStore: venueStore) { venue in
                selectedVenue = venue
            }
        }
        .sheet(isPresented: $showKickoffFirstHalf) {
            MatchKickoffView(
                matchViewModel: matchViewModel,
                phase: .firstHalf,
                onConfirmStart: { onStarted?(matchViewModel) }
            )
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            Section("Teams") {
                teamSelectionRow(
                    title: "Home Team",
                    accessibilityLabel: "Select Home Team from Library",
                    teamName: $homeTeam,
                    selectedTeam: $selectedHomeTeam,
                    useCustom: $useCustomHomeTeam,
                    showingPicker: $showingHomeTeamPicker
                )
                teamSelectionRow(
                    title: "Away Team",
                    accessibilityLabel: "Select Away Team from Library",
                    teamName: $awayTeam,
                    selectedTeam: $selectedAwayTeam,
                    useCustom: $useCustomAwayTeam,
                    showingPicker: $showingAwayTeamPicker
                )
                if let msg = validationMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(msg)")
                }
            }

            Section("Competition (Optional)") {
                Button {
                    showingCompetitionPicker = true
                } label: {
                    HStack {
                        Text("Competition")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedCompetition?.name ?? "None")
                            .foregroundStyle(selectedCompetition == nil ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityLabel("Select Competition from Library")

                if selectedCompetition != nil {
                    Button("Clear Selection") {
                        selectedCompetition = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .headerProminence(.increased)

            Section("Venue (Optional)") {
                Button {
                    showingVenuePicker = true
                } label: {
                    HStack {
                        Text("Venue")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedVenue?.name ?? "None")
                            .foregroundStyle(selectedVenue == nil ? .secondary : .primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityLabel("Select Venue from Library")

                if selectedVenue != nil {
                    Button("Clear Selection") {
                        selectedVenue = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .headerProminence(.increased)

            Section("Configuration") {
                Stepper(value: $durationMinutes, in: 30...150, step: 5) {
                    LabeledContent("Duration", value: "\(durationMinutes) min")
                }
                Stepper(value: $halfTimeMinutes, in: 5...30, step: 5) {
                    LabeledContent("Half‑time", value: "\(halfTimeMinutes) min")
                }
                Toggle("Extra Time", isOn: $hasExtraTime)
                if hasExtraTime {
                    Stepper(value: $etHalfMinutes, in: 5...30, step: 5) {
                        LabeledContent("ET half length", value: "\(etHalfMinutes) min")
                    }
                }
                Toggle("Penalties", isOn: $hasPenalties)
                if hasPenalties {
                    Stepper(value: $penaltyRounds, in: 1...10) {
                        LabeledContent("Initial rounds", value: "\(penaltyRounds)")
                    }
                }
            }

            Section {
                Button {
                    startMatch()
                } label: {
                    Label("Start Match", systemImage: "play.circle.fill")
                }
                .disabled(!isValid)
            }
        }
    }

    @ViewBuilder
    private func teamSelectionRow(
        title: String,
        accessibilityLabel: String,
        teamName: Binding<String>,
        selectedTeam: Binding<TeamRecord?>,
        useCustom: Binding<Bool>,
        showingPicker: Binding<Bool>
    ) -> some View {
        if useCustom.wrappedValue {
            TextField(title, text: teamName)
                .textInputAutocapitalization(.words)
                .onChange(of: teamName.wrappedValue) { _ in
                    if selectedTeam.wrappedValue != nil {
                        selectedTeam.wrappedValue = nil
                    }
                    validate()
                }
            Button("Select from Library") {
                useCustom.wrappedValue = false
                showingPicker.wrappedValue = true
            }
            .font(.caption)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(accessibilityLabel)
        } else {
            Button {
                showingPicker.wrappedValue = true
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    let selected = selectedTeam.wrappedValue
                    let displayName = selected?.name ?? teamName.wrappedValue
                    Text(selected == nil ? "Select..." : displayName)
                        .foregroundStyle(selected == nil ? .secondary : .primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel(accessibilityLabel)

            Button("Use Custom Name") {
                useCustom.wrappedValue = true
                selectedTeam.wrappedValue = nil
                validate()
            }
            .font(.caption)
            .foregroundStyle(Color.accentColor)
        }
    }

    private var isValid: Bool { validate() }

    @discardableResult
    private func validate() -> Bool {
        func validTeam(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "-&'."))
                .isSuperset(of: CharacterSet(charactersIn: trimmed))
        }

        if !validTeam(homeTeam) { validationMessage = "Enter a valid Home team (max 40)."; return false }
        if !validTeam(awayTeam) { validationMessage = "Enter a valid Away team (max 40)."; return false }
        validationMessage = nil
        return true
    }

    private func startMatch() {
        var match = Match(
            homeTeam: homeTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            awayTeam: awayTeam.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: TimeInterval(durationMinutes * 60),
            numberOfPeriods: 2,
            halfTimeLength: TimeInterval(halfTimeMinutes * 60),
            extraTimeHalfLength: TimeInterval(etHalfMinutes * 60),
            hasExtraTime: hasExtraTime,
            hasPenalties: hasPenalties,
            penaltyInitialRounds: penaltyRounds
        )

        match.homeTeamId = selectedHomeTeam?.id
        match.awayTeamId = selectedAwayTeam?.id
        match.competitionId = selectedCompetition?.id
        match.competitionName = selectedCompetition?.name
        match.venueId = selectedVenue?.id
        match.venueName = selectedVenue?.name

        matchViewModel.newMatch = match
        matchViewModel.createMatch()
        // Defer kickoff + start to first-half kickoff sheet
        showKickoffFirstHalf = true
    }
}

#Preview {
    let vm = MatchViewModel(haptics: NoopHaptics())
    let store = InMemoryTeamLibraryStore()
    _ = try? store.createTeam(name: "Arsenal", shortName: "ARS", division: "Premier League")
    _ = try? store.createTeam(name: "Real Madrid", shortName: "RMA", division: "La Liga")
    let competitionStore = InMemoryCompetitionLibraryStore()
    _ = try? competitionStore.create(name: "Premier League", level: "Professional")
    _ = try? competitionStore.create(name: "FA Cup", level: "Knockout")
    let venueStore = InMemoryVenueLibraryStore()
    _ = try? venueStore.create(name: "Wembley Stadium", city: "London", country: "England")
    _ = try? venueStore.create(name: "Allianz Arena", city: "Munich", country: "Germany")
    return NavigationStack {
        MatchSetupView(
            matchViewModel: vm,
            teamStore: store,
            competitionStore: competitionStore,
            venueStore: venueStore
        )
    }
}
