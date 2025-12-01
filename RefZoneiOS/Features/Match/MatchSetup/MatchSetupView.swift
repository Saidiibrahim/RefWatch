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
    let scheduledMatch: ScheduledMatch?

    @State private var isEditing: Bool
    @State private var homeTeam: String
    @State private var awayTeam: String
    @State private var selectedHomeTeam: TeamRecord?
    @State private var selectedAwayTeam: TeamRecord?
    @State private var useCustomHomeTeam: Bool
    @State private var useCustomAwayTeam: Bool
    @State private var showingHomeTeamPicker = false
    @State private var showingAwayTeamPicker = false
    @State private var selectedCompetition: CompetitionRecord?
    @State private var selectedVenue: VenueRecord?
    @State private var showingCompetitionPicker = false
    @State private var showingVenuePicker = false
    @State private var durationMinutes: Int
    @State private var halfTimeMinutes: Int
    @State private var hasExtraTime: Bool
    @State private var etHalfMinutes: Int
    @State private var hasPenalties: Bool
    @State private var penaltyRounds: Int

    @State private var showKickoffFirstHalf: Bool = false
    @State private var originalSnapshot: SetupSnapshot

    private struct SetupSnapshot {
        var homeTeam: String
        var awayTeam: String
        var selectedHomeTeam: TeamRecord?
        var selectedAwayTeam: TeamRecord?
        var useCustomHomeTeam: Bool
        var useCustomAwayTeam: Bool
        var selectedCompetition: CompetitionRecord?
        var selectedVenue: VenueRecord?
        var durationMinutes: Int
        var halfTimeMinutes: Int
        var hasExtraTime: Bool
        var etHalfMinutes: Int
        var hasPenalties: Bool
        var penaltyRounds: Int
    }

    init(
        matchViewModel: MatchViewModel,
        teamStore: TeamLibraryStoring,
        competitionStore: CompetitionLibraryStoring,
        venueStore: VenueLibraryStoring,
        onStarted: ((MatchViewModel) -> Void)? = nil,
        scheduledMatch: ScheduledMatch? = nil,
        prefillTeams: (String, String)? = nil
    ) {
        self.matchViewModel = matchViewModel
        self.teamStore = teamStore
        self.competitionStore = competitionStore
        self.venueStore = venueStore
        self.onStarted = onStarted
        self.scheduledMatch = scheduledMatch

        let initialHomeTeam = scheduledMatch?.homeTeam ?? prefillTeams?.0 ?? "Home"
        let initialAwayTeam = scheduledMatch?.awayTeam ?? prefillTeams?.1 ?? "Away"
        let initialSelectedHomeTeam: TeamRecord? = nil
        let initialSelectedAwayTeam: TeamRecord? = nil
        let initialUseCustomHomeTeam = true
        let initialUseCustomAwayTeam = true
        let initialSelectedCompetition: CompetitionRecord? = nil
        let initialSelectedVenue: VenueRecord? = nil
        let initialDuration = 90
        let initialHalfTime = 15
        let initialHasExtraTime = false
        let initialEtHalf = 15
        let initialHasPenalties = false
        let initialPenaltyRounds = 5

        _homeTeam = State(initialValue: initialHomeTeam)
        _awayTeam = State(initialValue: initialAwayTeam)
        _selectedHomeTeam = State(initialValue: initialSelectedHomeTeam)
        _selectedAwayTeam = State(initialValue: initialSelectedAwayTeam)
        _useCustomHomeTeam = State(initialValue: initialUseCustomHomeTeam)
        _useCustomAwayTeam = State(initialValue: initialUseCustomAwayTeam)
        _selectedCompetition = State(initialValue: initialSelectedCompetition)
        _selectedVenue = State(initialValue: initialSelectedVenue)
        _durationMinutes = State(initialValue: initialDuration)
        _halfTimeMinutes = State(initialValue: initialHalfTime)
        _hasExtraTime = State(initialValue: initialHasExtraTime)
        _etHalfMinutes = State(initialValue: initialEtHalf)
        _hasPenalties = State(initialValue: initialHasPenalties)
        _penaltyRounds = State(initialValue: initialPenaltyRounds)
        _isEditing = State(initialValue: scheduledMatch == nil)
        _originalSnapshot = State(initialValue: SetupSnapshot(
            homeTeam: initialHomeTeam,
            awayTeam: initialAwayTeam,
            selectedHomeTeam: initialSelectedHomeTeam,
            selectedAwayTeam: initialSelectedAwayTeam,
            useCustomHomeTeam: initialUseCustomHomeTeam,
            useCustomAwayTeam: initialUseCustomAwayTeam,
            selectedCompetition: initialSelectedCompetition,
            selectedVenue: initialSelectedVenue,
            durationMinutes: initialDuration,
            halfTimeMinutes: initialHalfTime,
            hasExtraTime: initialHasExtraTime,
            etHalfMinutes: initialEtHalf,
            hasPenalties: initialHasPenalties,
            penaltyRounds: initialPenaltyRounds
        ))
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
        .toolbar {
            if scheduledMatch != nil {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cancelEditing() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { finishEditing() }
                            .disabled(!isValid)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { startEditing() }
                    }
                }
            }
        }
        .sheet(isPresented: $showingHomeTeamPicker) {
            TeamPickerSheet(teamStore: teamStore) { team in
                selectedHomeTeam = team
                homeTeam = team.name
                useCustomHomeTeam = false
            }
        }
        .sheet(isPresented: $showingAwayTeamPicker) {
            TeamPickerSheet(teamStore: teamStore) { team in
                selectedAwayTeam = team
                awayTeam = team.name
                useCustomAwayTeam = false
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
                    showingPicker: $showingHomeTeamPicker,
                    isEditing: isEditing
                )
                teamSelectionRow(
                    title: "Away Team",
                    accessibilityLabel: "Select Away Team from Library",
                    teamName: $awayTeam,
                    selectedTeam: $selectedAwayTeam,
                    useCustom: $useCustomAwayTeam,
                    showingPicker: $showingAwayTeamPicker,
                    isEditing: isEditing
                )
                if let msg = validationErrorMessage, isEditing {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Validation error: \(msg)")
                }
            }

            Section("Competition (Optional)") {
                if isEditing {
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
                } else {
                    LabeledContent("Competition") {
                        Text(selectedCompetition?.name ?? "None")
                            .foregroundStyle(selectedCompetition == nil ? .secondary : .primary)
                    }
                }
            }
            .headerProminence(.increased)

            Section("Venue (Optional)") {
                if isEditing {
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
                } else {
                    LabeledContent("Venue") {
                        Text(selectedVenue?.name ?? "None")
                            .foregroundStyle(selectedVenue == nil ? .secondary : .primary)
                    }
                }
            }
            .headerProminence(.increased)

            Section("Configuration") {
                if isEditing {
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
                } else {
                    LabeledContent("Duration", value: "\(durationMinutes) min")
                    LabeledContent("Half‑time", value: "\(halfTimeMinutes) min")
                    LabeledContent("Extra Time", value: hasExtraTime ? "Enabled" : "Off")
                    if hasExtraTime {
                        LabeledContent("ET half length", value: "\(etHalfMinutes) min")
                    }
                    LabeledContent("Penalties", value: hasPenalties ? "Enabled" : "Off")
                    if hasPenalties {
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
        showingPicker: Binding<Bool>,
        isEditing: Bool
    ) -> some View {
        if isEditing {
            if useCustom.wrappedValue {
                TextField(title, text: teamName)
                    .textInputAutocapitalization(.words)
                    .onChange(of: teamName.wrappedValue) {
                        if selectedTeam.wrappedValue != nil {
                            selectedTeam.wrappedValue = nil
                        }
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
                }
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }
        } else {
            let selected = selectedTeam.wrappedValue
            let displayName = selected?.name ?? teamName.wrappedValue
            LabeledContent(title) {
                Text(displayName.isEmpty ? "—" : displayName)
                    .foregroundStyle(displayName.isEmpty ? .secondary : .primary)
            }
        }
    }

    private var isValid: Bool { validationErrorMessage == nil }

    private var validationErrorMessage: String? {
        validationError(homeTeam: homeTeam, awayTeam: awayTeam)
    }

    private func startEditing() {
        isEditing = true
    }

    private func cancelEditing() {
        apply(snapshot: originalSnapshot)
        isEditing = false
    }

    private func finishEditing() {
        guard isValid else { return }
        originalSnapshot = makeSnapshot()
        isEditing = false
    }

    private func makeSnapshot() -> SetupSnapshot {
        SetupSnapshot(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            selectedHomeTeam: selectedHomeTeam,
            selectedAwayTeam: selectedAwayTeam,
            useCustomHomeTeam: useCustomHomeTeam,
            useCustomAwayTeam: useCustomAwayTeam,
            selectedCompetition: selectedCompetition,
            selectedVenue: selectedVenue,
            durationMinutes: durationMinutes,
            halfTimeMinutes: halfTimeMinutes,
            hasExtraTime: hasExtraTime,
            etHalfMinutes: etHalfMinutes,
            hasPenalties: hasPenalties,
            penaltyRounds: penaltyRounds
        )
    }

    private func apply(snapshot: SetupSnapshot) {
        homeTeam = snapshot.homeTeam
        awayTeam = snapshot.awayTeam
        selectedHomeTeam = snapshot.selectedHomeTeam
        selectedAwayTeam = snapshot.selectedAwayTeam
        useCustomHomeTeam = snapshot.useCustomHomeTeam
        useCustomAwayTeam = snapshot.useCustomAwayTeam
        selectedCompetition = snapshot.selectedCompetition
        selectedVenue = snapshot.selectedVenue
        durationMinutes = snapshot.durationMinutes
        halfTimeMinutes = snapshot.halfTimeMinutes
        hasExtraTime = snapshot.hasExtraTime
        etHalfMinutes = snapshot.etHalfMinutes
        hasPenalties = snapshot.hasPenalties
        penaltyRounds = snapshot.penaltyRounds
    }

    private func validationError(homeTeam: String, awayTeam: String) -> String? {
        func validTeam(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "-&'."))
                .isSuperset(of: CharacterSet(charactersIn: trimmed))
        }

        if !validTeam(homeTeam) { return "Enter a valid Home team (max 40)." }
        if !validTeam(awayTeam) { return "Enter a valid Away team (max 40)." }
        return nil
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

        // CRITICAL: Link to schedule if starting from one
        if let sched = scheduledMatch {
            match.scheduledMatchId = sched.id
        }

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
