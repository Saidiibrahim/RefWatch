//
//  MatchSetupView.swift
//  RefWatchiOS
//
//  iOS setup form for creating and starting a match using RefWatchCore.
//  Skeleton only — navigation is delegated via optional onStarted closure.
//

import RefWatchCore
import SwiftUI

struct MatchSetupView: View {
  let matchViewModel: MatchViewModel
  let teamStore: TeamLibraryStoring
  let competitionStore: CompetitionLibraryStoring
  let venueStore: VenueLibraryStoring
  var onStarted: ((MatchViewModel) -> Void)?
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
    prefillTeams: (String, String)? = nil)
  {
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
      penaltyRounds: initialPenaltyRounds))
  }

  @EnvironmentObject private var authController: SupabaseAuthController

  var body: some View {
    Group {
      if self.authController.isSignedIn {
        self.formContent
      } else {
        SignedOutFeaturePlaceholder(
          description: "Sign in to configure and start new matches on your iPhone.")
      }
    }
    .navigationTitle("Match Setup")
    .toolbar {
      if self.scheduledMatch != nil {
        if self.isEditing {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { self.cancelEditing() }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { self.finishEditing() }
              .disabled(!self.isValid)
          }
        } else {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Edit") { self.startEditing() }
          }
        }
      }
    }
    .sheet(isPresented: self.$showingHomeTeamPicker) {
      TeamPickerSheet(teamStore: self.teamStore) { team in
        self.selectedHomeTeam = team
        self.homeTeam = team.name
        self.useCustomHomeTeam = false
      }
    }
    .sheet(isPresented: self.$showingAwayTeamPicker) {
      TeamPickerSheet(teamStore: self.teamStore) { team in
        self.selectedAwayTeam = team
        self.awayTeam = team.name
        self.useCustomAwayTeam = false
      }
    }
    .sheet(isPresented: self.$showingCompetitionPicker) {
      CompetitionPickerSheet(competitionStore: self.competitionStore) { competition in
        self.selectedCompetition = competition
      }
    }
    .sheet(isPresented: self.$showingVenuePicker) {
      VenuePickerSheet(venueStore: self.venueStore) { venue in
        self.selectedVenue = venue
      }
    }
    .sheet(isPresented: self.$showKickoffFirstHalf) {
      MatchKickoffView(
        matchViewModel: self.matchViewModel,
        phase: .firstHalf,
        onConfirmStart: { self.onStarted?(self.matchViewModel) })
    }
  }

  @ViewBuilder
  private var formContent: some View {
    Form {
      Section("Teams") {
        self.teamSelectionRow(
          title: "Home Team",
          accessibilityLabel: "Select Home Team from Library",
          bindings: TeamSelectionBindings(
            teamName: self.$homeTeam,
            selectedTeam: self.$selectedHomeTeam,
            useCustom: self.$useCustomHomeTeam,
            showingPicker: self.$showingHomeTeamPicker),
          isEditing: self.isEditing)
        self.teamSelectionRow(
          title: "Away Team",
          accessibilityLabel: "Select Away Team from Library",
          bindings: TeamSelectionBindings(
            teamName: self.$awayTeam,
            selectedTeam: self.$selectedAwayTeam,
            useCustom: self.$useCustomAwayTeam,
            showingPicker: self.$showingAwayTeamPicker),
          isEditing: self.isEditing)
        if let msg = validationErrorMessage, isEditing {
          Text(msg)
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityLabel("Validation error: \(msg)")
        }
      }

      Section("Competition (Optional)") {
        if self.isEditing {
          Button {
            self.showingCompetitionPicker = true
          } label: {
            HStack {
              Text("Competition")
                .foregroundStyle(.primary)
              Spacer()
              Text(self.selectedCompetition?.name ?? "None")
                .foregroundStyle(self.selectedCompetition == nil ? .secondary : .primary)
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          .accessibilityLabel("Select Competition from Library")

          if self.selectedCompetition != nil {
            Button("Clear Selection") {
              self.selectedCompetition = nil
            }
            .font(.caption)
            .foregroundStyle(.red)
          }
        } else {
          LabeledContent("Competition") {
            Text(self.selectedCompetition?.name ?? "None")
              .foregroundStyle(self.selectedCompetition == nil ? .secondary : .primary)
          }
        }
      }
      .headerProminence(.increased)

      Section("Venue (Optional)") {
        if self.isEditing {
          Button {
            self.showingVenuePicker = true
          } label: {
            HStack {
              Text("Venue")
                .foregroundStyle(.primary)
              Spacer()
              Text(self.selectedVenue?.name ?? "None")
                .foregroundStyle(self.selectedVenue == nil ? .secondary : .primary)
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          .accessibilityLabel("Select Venue from Library")

          if self.selectedVenue != nil {
            Button("Clear Selection") {
              self.selectedVenue = nil
            }
            .font(.caption)
            .foregroundStyle(.red)
          }
        } else {
          LabeledContent("Venue") {
            Text(self.selectedVenue?.name ?? "None")
              .foregroundStyle(self.selectedVenue == nil ? .secondary : .primary)
          }
        }
      }
      .headerProminence(.increased)

      Section("Configuration") {
        if self.isEditing {
          Stepper(value: self.$durationMinutes, in: 30...150, step: 5) {
            LabeledContent("Duration", value: "\(self.durationMinutes) min")
          }
          Stepper(value: self.$halfTimeMinutes, in: 5...30, step: 5) {
            LabeledContent("Half‑time", value: "\(self.halfTimeMinutes) min")
          }
          Toggle("Extra Time", isOn: self.$hasExtraTime)
          if self.hasExtraTime {
            Stepper(value: self.$etHalfMinutes, in: 5...30, step: 5) {
              LabeledContent("ET half length", value: "\(self.etHalfMinutes) min")
            }
          }
          Toggle("Penalties", isOn: self.$hasPenalties)
          if self.hasPenalties {
            Stepper(value: self.$penaltyRounds, in: 1...10) {
              LabeledContent("Initial rounds", value: "\(self.penaltyRounds)")
            }
          }
        } else {
          LabeledContent("Duration", value: "\(self.durationMinutes) min")
          LabeledContent("Half‑time", value: "\(self.halfTimeMinutes) min")
          LabeledContent("Extra Time", value: self.hasExtraTime ? "Enabled" : "Off")
          if self.hasExtraTime {
            LabeledContent("ET half length", value: "\(self.etHalfMinutes) min")
          }
          LabeledContent("Penalties", value: self.hasPenalties ? "Enabled" : "Off")
          if self.hasPenalties {
            LabeledContent("Initial rounds", value: "\(self.penaltyRounds)")
          }
        }
      }

      Section {
        Button {
          self.startMatch()
        } label: {
          Label("Start Match", systemImage: "play.circle.fill")
        }
        .disabled(!self.isValid)
      }
    }
  }

  private struct TeamSelectionBindings {
    let teamName: Binding<String>
    let selectedTeam: Binding<TeamRecord?>
    let useCustom: Binding<Bool>
    let showingPicker: Binding<Bool>
  }

  @ViewBuilder
  private func teamSelectionRow(
    title: String,
    accessibilityLabel: String,
    bindings: TeamSelectionBindings,
    isEditing: Bool) -> some View
  {
    if isEditing {
      if bindings.useCustom.wrappedValue {
        TextField(title, text: bindings.teamName)
          .textInputAutocapitalization(.words)
          .onChange(of: bindings.teamName.wrappedValue) {
            if bindings.selectedTeam.wrappedValue != nil {
              bindings.selectedTeam.wrappedValue = nil
            }
          }
        Button("Select from Library") {
          bindings.useCustom.wrappedValue = false
          bindings.showingPicker.wrappedValue = true
        }
        .font(.caption)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(accessibilityLabel)
      } else {
        Button {
          bindings.showingPicker.wrappedValue = true
        } label: {
          HStack {
            Text(title)
              .foregroundStyle(.primary)
            Spacer()
            let selected = bindings.selectedTeam.wrappedValue
            let displayName = selected?.name ?? bindings.teamName.wrappedValue
            Text(selected == nil ? "Select..." : displayName)
              .foregroundStyle(selected == nil ? .secondary : .primary)
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }
        .accessibilityLabel(accessibilityLabel)

        Button("Use Custom Name") {
          bindings.useCustom.wrappedValue = true
          bindings.selectedTeam.wrappedValue = nil
        }
        .font(.caption)
        .foregroundStyle(Color.accentColor)
      }
    } else {
      let selected = bindings.selectedTeam.wrappedValue
      let displayName = selected?.name ?? bindings.teamName.wrappedValue
      LabeledContent(title) {
        Text(displayName.isEmpty ? "—" : displayName)
          .foregroundStyle(displayName.isEmpty ? .secondary : .primary)
      }
    }
  }

  private var isValid: Bool { self.validationErrorMessage == nil }

  private var validationErrorMessage: String? {
    self.validationError(homeTeam: self.homeTeam, awayTeam: self.awayTeam)
  }

  private func startEditing() {
    self.isEditing = true
  }

  private func cancelEditing() {
    self.apply(snapshot: self.originalSnapshot)
    self.isEditing = false
  }

  private func finishEditing() {
    guard self.isValid else { return }
    self.originalSnapshot = self.makeSnapshot()
    self.isEditing = false
  }

  private func makeSnapshot() -> SetupSnapshot {
    SetupSnapshot(
      homeTeam: self.homeTeam,
      awayTeam: self.awayTeam,
      selectedHomeTeam: self.selectedHomeTeam,
      selectedAwayTeam: self.selectedAwayTeam,
      useCustomHomeTeam: self.useCustomHomeTeam,
      useCustomAwayTeam: self.useCustomAwayTeam,
      selectedCompetition: self.selectedCompetition,
      selectedVenue: self.selectedVenue,
      durationMinutes: self.durationMinutes,
      halfTimeMinutes: self.halfTimeMinutes,
      hasExtraTime: self.hasExtraTime,
      etHalfMinutes: self.etHalfMinutes,
      hasPenalties: self.hasPenalties,
      penaltyRounds: self.penaltyRounds)
  }

  private func apply(snapshot: SetupSnapshot) {
    self.homeTeam = snapshot.homeTeam
    self.awayTeam = snapshot.awayTeam
    self.selectedHomeTeam = snapshot.selectedHomeTeam
    self.selectedAwayTeam = snapshot.selectedAwayTeam
    self.useCustomHomeTeam = snapshot.useCustomHomeTeam
    self.useCustomAwayTeam = snapshot.useCustomAwayTeam
    self.selectedCompetition = snapshot.selectedCompetition
    self.selectedVenue = snapshot.selectedVenue
    self.durationMinutes = snapshot.durationMinutes
    self.halfTimeMinutes = snapshot.halfTimeMinutes
    self.hasExtraTime = snapshot.hasExtraTime
    self.etHalfMinutes = snapshot.etHalfMinutes
    self.hasPenalties = snapshot.hasPenalties
    self.penaltyRounds = snapshot.penaltyRounds
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
      awayTeam: self.awayTeam.trimmingCharacters(in: .whitespacesAndNewlines),
      duration: TimeInterval(self.durationMinutes * 60),
      numberOfPeriods: 2,
      halfTimeLength: TimeInterval(self.halfTimeMinutes * 60),
      extraTimeHalfLength: TimeInterval(self.etHalfMinutes * 60),
      hasExtraTime: self.hasExtraTime,
      hasPenalties: self.hasPenalties,
      penaltyInitialRounds: self.penaltyRounds)

    // CRITICAL: Link to schedule if starting from one
    if let sched = scheduledMatch {
      match.scheduledMatchId = sched.id
    }

    match.homeTeamId = self.selectedHomeTeam?.id
    match.awayTeamId = self.selectedAwayTeam?.id
    match.competitionId = self.selectedCompetition?.id
    match.competitionName = self.selectedCompetition?.name
    match.venueId = self.selectedVenue?.id
    match.venueName = self.selectedVenue?.name

    self.matchViewModel.newMatch = match
    self.matchViewModel.createMatch()
    // Defer kickoff + start to first-half kickoff sheet
    self.showKickoffFirstHalf = true
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
      venueStore: venueStore)
  }
}
