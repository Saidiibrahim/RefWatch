// SubstitutionFlow.swift
// Description: Hub-and-spoke flow for recording one or more substitutions on watchOS.

import RefWatchCore
import SwiftUI

struct SubstitutionFlow: View {
  let team: TeamDetailsView.TeamType
  let matchViewModel: MatchViewModel
  let onComplete: () -> Void

  @Environment(SettingsViewModel.self) private var settingsViewModel
  @Environment(\.theme) private var theme
  @State private var activeRoute: SubstitutionRoute?
  @State private var playersOff: [SubstitutionSelection] = []
  @State private var playersOn: [SubstitutionSelection] = []
  @State private var confirmationSnapshot: MatchViewModel.EventSnapshot?

  var body: some View {
    List {
      self.summaryCard
      self.selectionButton(for: .playerOff)
      self.selectionButton(for: .playerOn)
      self.doneButton
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, self.theme.components.listRowVerticalInset)
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle("Sub")
    .navigationDestination(item: self.$activeRoute) { route in
      switch route {
      case let .selection(target):
        self.selectionDestination(for: target)
      case .confirmation:
        SubstitutionBatchConfirmationView(
          pairs: self.orderedPairs,
          matchTime: self.confirmationSnapshot?.matchTime ?? self.matchViewModel.matchTime,
          onConfirm: {
            self.commitBatch()
          })
      }
    }
  }

  private var summaryCard: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
        HStack {
          Text("Substitutions made:")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)

          Spacer()

          Text("\(self.orderedPairs.count)")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)
        }

        if self.canSubmit == false, self.hasAnySelections {
          Text("Select equal players off and on")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        } else {
          Text("All saved substitutions share one match time")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
      }
    }
    .listRowInsets(self.rowInsets)
    .listRowBackground(Color.clear)
  }

  private func selectionButton(for target: SubstitutionTarget) -> some View {
    Button {
      self.confirmationSnapshot = nil
      self.navigate(to: .selection(target))
    } label: {
      NavigationRowLabel(
        title: target.title,
        subtitle: self.selectionSummary(for: target),
        showChevron: true)
    }
    .buttonStyle(.plain)
    .listRowInsets(self.rowInsets)
    .listRowBackground(Color.clear)
  }

  private var doneButton: some View {
    Button {
      self.handleDone()
    } label: {
      ThemeCardContainer(role: self.canSubmit ? .positive : .secondary, minHeight: 72) {
        Text("Done")
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(
            self.canSubmit ? self.theme.colors.textInverted : self.theme.colors.textSecondary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .buttonStyle(.plain)
    .disabled(self.canSubmit == false)
    .listRowInsets(self.rowInsets)
    .listRowBackground(Color.clear)
  }

  @ViewBuilder
  private func selectionDestination(for target: SubstitutionTarget) -> some View {
    switch self.resolvedSelectionSource {
    case let .frozenSheet(lineup):
      let players = self.frozenSheetPlayers(for: target, lineup: lineup)
      if players.isEmpty {
        SubstitutionUnavailableView(
          title: target.title,
          message: self.frozenSheetEmptyMessage(for: target))
      } else {
        SubstitutionPlayerSelectionView(
          title: target.title,
          players: players,
          selections: self.binding(for: target))
      }
    case .manualOnly:
      SubstitutionNumberCollectorView(
        title: target.title,
        selections: self.binding(for: target))
    case .legacyLibrary:
      if let roster = self.resolvedPlayers(for: target), roster.isEmpty == false {
        SubstitutionPlayerSelectionView(
          title: target.title,
          players: roster,
          selections: self.binding(for: target))
      } else {
        SubstitutionNumberCollectorView(
          title: target.title,
          selections: self.binding(for: target))
      }
    }
  }

  private func binding(for target: SubstitutionTarget) -> Binding<[SubstitutionSelection]> {
    switch target {
    case .playerOff:
      self.$playersOff
    case .playerOn:
      self.$playersOn
    }
  }

  private func resolvedPlayers(for target: SubstitutionTarget) -> [SubstitutionSelectablePlayer]? {
    switch self.resolvedSelectionSource {
    case let .frozenSheet(lineup):
      return self.frozenSheetPlayers(for: target, lineup: lineup)
    case let .legacyLibrary(players):
      return players.map(SubstitutionSelectablePlayer.init(player:))
    case .manualOnly:
      return nil
    }
  }

  private func frozenSheetPlayers(
    for target: SubstitutionTarget,
    lineup: MatchSheetResolvedLineup) -> [SubstitutionSelectablePlayer]
  {
    switch target {
    case .playerOff:
      return lineup.onField.map(SubstitutionSelectablePlayer.init(entry:))
    case .playerOn:
      return lineup.unusedSubstitutes.map(SubstitutionSelectablePlayer.init(entry:))
    }
  }

  private func frozenSheetEmptyMessage(for target: SubstitutionTarget) -> String {
    switch target {
    case .playerOff:
      return "No eligible on-field players remain on the official match sheet."
    case .playerOn:
      return "No unused substitutes remain on the official match sheet."
    }
  }

  private var resolvedSelectionSource: MatchParticipantSelectionSource {
    guard let match = self.matchViewModel.currentMatch else { return .manualOnly }
    return MatchParticipantSelectionResolver.resolve(
      match: match,
      team: self.teamSide,
      libraryTeams: self.matchViewModel.libraryTeams,
      events: self.matchViewModel.matchEvents)
  }

  private func selectionSummary(for target: SubstitutionTarget) -> String {
    let selections = self.selections(for: target)
    guard selections.isEmpty == false else { return "Select player" }
    return selections.enumerated().map { index, selection in
      "\(index + 1). \(selection.displayLabel)"
    }.joined(separator: ", ")
  }

  private func selections(for target: SubstitutionTarget) -> [SubstitutionSelection] {
    switch target {
    case .playerOff:
      self.playersOff
    case .playerOn:
      self.playersOn
    }
  }

  private var orderedPairs: [SubstitutionPair] {
    Array(zip(self.playersOff, self.playersOn)).map { playerOff, playerOn in
      SubstitutionPair(playerOff: playerOff, playerOn: playerOn)
    }
  }

  private var canSubmit: Bool {
    self.playersOff.isEmpty == false
      && self.playersOff.count == self.playersOn.count
  }

  private var hasAnySelections: Bool {
    self.playersOff.isEmpty == false || self.playersOn.isEmpty == false
  }

  private func handleDone() {
    guard self.canSubmit else { return }
    if self.settingsViewModel.settings.confirmSubstitutions {
      self.confirmationSnapshot = self.matchViewModel.captureEventSnapshotForConfirmation()
      self.navigate(to: .confirmation)
    } else {
      self.commitBatch()
    }
  }

  private func navigate(to route: SubstitutionRoute) {
    self.activeRoute = nil
    Task { @MainActor in
      self.activeRoute = route
    }
  }

  private func commitBatch() {
    guard self.canSubmit else { return }
    let substitutions = self.orderedPairs.map { pair in
      SubstitutionDetails(
        playerOut: pair.playerOff.number,
        playerIn: pair.playerOn.number,
        playerOutName: pair.playerOff.name,
        playerInName: pair.playerOn.name)
    }

    if let confirmationSnapshot {
      self.matchViewModel.recordSubstitutions(
        team: self.teamSide,
        substitutions: substitutions,
        snapshot: confirmationSnapshot)
      self.confirmationSnapshot = nil
    } else {
      self.matchViewModel.recordSubstitutions(team: self.teamSide, substitutions: substitutions)
    }
    self.onComplete()
  }

  private var teamSide: TeamSide {
    self.team == .home ? .home : .away
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: 0,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: 0)
  }
}

private struct SubstitutionUnavailableView: View {
  let title: String
  let message: String

  @Environment(\.theme) private var theme

  var body: some View {
    ScrollView {
      ThemeCardContainer(role: .secondary, minHeight: 120) {
        VStack(alignment: .leading, spacing: self.theme.spacing.s) {
          Text("No Eligible Players")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)

          Text(self.message)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, self.theme.spacing.xs)
      .padding(.vertical, self.theme.spacing.s)
    }
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle(self.title)
  }
}

private enum SubstitutionTarget: String, Hashable {
  case playerOff
  case playerOn

  var title: String {
    switch self {
    case .playerOff:
      "Player(s) off"
    case .playerOn:
      "Player(s) on"
    }
  }
}

private enum SubstitutionRoute: Identifiable, Hashable {
  case selection(SubstitutionTarget)
  case confirmation

  var id: String {
    switch self {
    case let .selection(target):
      return target.rawValue
    case .confirmation:
      return "confirmation"
    }
  }
}

private struct SubstitutionSelection: Identifiable, Equatable, Hashable {
  let id: UUID
  let participantId: UUID
  let number: Int?
  let name: String?

  init(
    id: UUID = UUID(),
    participantId: UUID = UUID(),
    number: Int? = nil,
    name: String? = nil)
  {
    self.id = id
    self.participantId = participantId
    self.number = number
    self.name = name?.trimmedOrNil
  }

  init(player: SubstitutionSelectablePlayer) {
    self.id = UUID()
    self.participantId = player.participantId
    self.number = player.number
    self.name = player.name.trimmedOrNil
  }

  var displayLabel: String {
    Self.formattedParticipant(number: self.number, name: self.name) ?? "Player"
  }

  private static func formattedParticipant(number: Int?, name: String?) -> String? {
    let trimmedName = name?.trimmedOrNil
    switch (number, trimmedName) {
    case let (number?, name?):
      return "#\(number) \(name)"
    case let (number?, nil):
      return "#\(number)"
    case let (nil, name?):
      return name
    case (nil, nil):
      return nil
    }
  }
}

private struct SubstitutionPair: Identifiable, Equatable {
  let id = UUID()
  let playerOff: SubstitutionSelection
  let playerOn: SubstitutionSelection
}

private struct SubstitutionSelectablePlayer: Identifiable, Equatable {
  let participantId: UUID
  let name: String
  let number: Int?
  let position: String?
  let notes: String?

  var id: UUID { self.participantId }

  init(player: MatchLibraryPlayer) {
    self.participantId = player.id
    self.name = player.name
    self.number = player.number
    self.position = player.position
    self.notes = player.notes
  }

  init(entry: MatchSheetPlayerEntry) {
    self.participantId = entry.entryId
    self.name = entry.displayName
    self.number = entry.shirtNumber
    self.position = entry.position
    self.notes = entry.notes
  }
}

private struct SubstitutionPlayerSelectionView: View {
  let title: String
  let players: [SubstitutionSelectablePlayer]
  @Binding var selections: [SubstitutionSelection]

  @Environment(\.theme) private var theme

  var body: some View {
    List {
      ForEach(self.players) { player in
        Button {
          self.toggle(player)
        } label: {
          self.row(for: player)
        }
        .buttonStyle(.plain)
        .listRowInsets(self.rowInsets)
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, self.theme.components.listRowVerticalInset)
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle(self.title)
  }

  private func row(for player: SubstitutionSelectablePlayer) -> some View {
    let order = self.selectionOrder(for: player)
    let isSelected = order != nil

    return HStack(spacing: self.theme.spacing.m) {
      VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
        Text(self.playerLabel(for: player))
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)

        if let order {
          Text("Selected \(order)")
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }

      if let order {
        Text("\(order)")
          .font(self.theme.typography.cardHeadline)
          .foregroundStyle(self.theme.colors.textPrimary)
          .padding(.horizontal, self.theme.spacing.s)
          .padding(.vertical, self.theme.spacing.xs)
          .background(Capsule().fill(Color.white.opacity(0.45)))
      }
    }
    .padding(.vertical, self.theme.spacing.m)
    .padding(.horizontal, self.theme.components.cardHorizontalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: 72, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
        .fill(isSelected ? Color.yellow.opacity(0.75) : self.theme.colors.backgroundElevated)
        .overlay(
          RoundedRectangle(cornerRadius: self.theme.components.cardCornerRadius, style: .continuous)
            .stroke(
              isSelected ? Color.yellow.opacity(0.95) : self.theme.colors.outlineMuted,
              lineWidth: isSelected ? 1.5 : 1)))
  }

  private func toggle(_ player: SubstitutionSelectablePlayer) {
    if let index = self.selections.firstIndex(where: { $0.participantId == player.participantId }) {
      self.selections.remove(at: index)
    } else {
      self.selections.append(SubstitutionSelection(player: player))
    }
  }

  private func selectionOrder(for player: SubstitutionSelectablePlayer) -> Int? {
    guard let index = self.selections.firstIndex(where: { $0.participantId == player.participantId }) else { return nil }
    return index + 1
  }

  private func playerLabel(for player: SubstitutionSelectablePlayer) -> String {
    let trimmedName = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
    switch (player.number, trimmedName.isEmpty ? nil : trimmedName) {
    case let (number?, name?):
      return "\(number). \(name)"
    case let (number?, nil):
      return "\(number). Player"
    case let (nil, name?):
      return name
    case (nil, nil):
      return "Player"
    }
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: 0,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: 0)
  }
}

private struct SubstitutionNumberCollectorView: View {
  let title: String
  @Binding var selections: [SubstitutionSelection]

  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @State private var numberString = ""
  @State private var editingSelectionID: UUID?

  var body: some View {
    ScrollView {
      VStack(spacing: self.theme.spacing.m) {
        if self.selections.isEmpty == false {
          ThemeCardContainer(role: .secondary) {
            VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
              Text("Selected")
                .font(self.theme.typography.cardHeadline)
                .foregroundStyle(self.theme.colors.textPrimary)

              ForEach(self.selections) { selection in
                HStack(spacing: self.theme.spacing.s) {
                  Button {
                    self.beginEditing(selection)
                  } label: {
                    Text(selection.displayLabel)
                      .font(self.theme.typography.cardMeta)
                      .foregroundStyle(self.theme.colors.textPrimary)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .buttonStyle(.plain)

                  Button {
                    self.remove(selection)
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundStyle(self.theme.colors.textSecondary)
                  }
                  .buttonStyle(.plain)
                }
              }

              Text(self.editingSelectionID == nil ? "Tap a number to edit" : "Editing selected number")
                .font(self.theme.typography.cardMeta)
                .foregroundStyle(self.theme.colors.textSecondary)
            }
          }
        }

        NumericKeypad(
          numberString: self.$numberString,
          maxDigits: 2,
          placeholder: self.title,
          placeholderColor: .gray,
          accessoryIcon: "person.badge.plus",
          accessoryColor: self.theme.colors.accentSecondary,
          onSubmit: {
            self.submitCurrentNumber()
          },
          onAccessoryTap: {
            self.addCurrentNumber()
          })
      }
      .padding(.horizontal, self.theme.spacing.xs)
      .padding(.vertical, self.theme.spacing.s)
    }
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle(self.title)
  }

  @discardableResult
  private func addCurrentNumber() -> Bool {
    guard let number = Int(self.numberString), number > 0 else { return false }

    if self.selections.contains(where: { $0.number == number && $0.id != self.editingSelectionID }) {
      return false
    }

    if let editingSelectionID,
       let index = self.selections.firstIndex(where: { $0.id == editingSelectionID })
    {
      self.selections[index] = SubstitutionSelection(
        id: editingSelectionID,
        number: number,
        name: nil)
      self.editingSelectionID = nil
    } else {
      self.selections.append(SubstitutionSelection(number: number, name: nil))
    }

    self.numberString = ""
    return true
  }

  private func submitCurrentNumber() {
    guard self.addCurrentNumber() else { return }
    guard self.selections.isEmpty == false else { return }
    self.dismiss()
  }

  private func beginEditing(_ selection: SubstitutionSelection) {
    self.editingSelectionID = selection.id
    self.numberString = selection.number.map(String.init) ?? ""
  }

  private func remove(_ selection: SubstitutionSelection) {
    self.selections.removeAll { $0.id == selection.id }
    if self.editingSelectionID == selection.id {
      self.editingSelectionID = nil
      self.numberString = ""
    }
  }
}

private struct SubstitutionBatchConfirmationView: View {
  let pairs: [SubstitutionPair]
  let matchTime: String
  let onConfirm: () -> Void

  @Environment(\.theme) private var theme

  var body: some View {
    List {
      ThemeCardContainer(role: .secondary, minHeight: 72) {
        VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
          Text("Shared match time")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textPrimary)

          Text(self.matchTime)
            .font(self.theme.typography.cardMeta)
            .foregroundStyle(self.theme.colors.textSecondary)
        }
      }
      .listRowInsets(self.rowInsets)
      .listRowBackground(Color.clear)

      ForEach(Array(self.pairs.enumerated()), id: \.offset) { index, pair in
        ThemeCardContainer(role: .secondary, minHeight: 72) {
          VStack(alignment: .leading, spacing: self.theme.spacing.xs) {
            Text("Sub \(index + 1)")
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)

            Text("\(pair.playerOff.displayLabel) -> \(pair.playerOn.displayLabel)")
              .font(self.theme.typography.cardHeadline)
              .foregroundStyle(self.theme.colors.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .listRowInsets(self.rowInsets)
        .listRowBackground(Color.clear)
      }

      Button {
        self.onConfirm()
      } label: {
        ThemeCardContainer(role: .positive, minHeight: 72) {
          Text("Save \(self.pairs.count) Subs")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textInverted)
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
      .buttonStyle(.plain)
      .listRowInsets(self.rowInsets)
      .listRowBackground(Color.clear)
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .padding(.vertical, self.theme.components.listRowVerticalInset)
    .background(self.theme.colors.backgroundPrimary)
    .navigationTitle("Confirm")
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: 0,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: 0)
  }
}

private extension String {
  var trimmedOrNil: String? {
    let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

// MARK: - Preview Support

#Preview("Batch Substitution") {
  let matchViewModel = previewSubstitutionMatchViewModel()

  return NavigationStack {
    SubstitutionFlow(
      team: .home,
      matchViewModel: matchViewModel,
      onComplete: {})
  }
  .environment(SettingsViewModel())
  .theme(DefaultTheme())
}

@MainActor
private func previewSubstitutionMatchViewModel() -> MatchViewModel {
  let homeTeamId = UUID()
  let awayTeamId = UUID()
  let viewModel = MatchViewModel(
    history: MockMatchHistoryService(),
    haptics: NoopHaptics())

  viewModel.updateLibrary(
    with: MatchLibrarySnapshot(
      teams: [
        MatchLibraryTeam(
          id: homeTeamId,
          name: "Arsenal",
          players: [
            MatchLibraryPlayer(id: UUID(), name: "Bob Smith", number: 1),
            MatchLibraryPlayer(id: UUID(), name: "James Woods", number: 2),
            MatchLibraryPlayer(id: UUID(), name: "Mike Robson", number: 3),
            MatchLibraryPlayer(id: UUID(), name: "Oliver Keeble", number: 4),
          ]),
        MatchLibraryTeam(id: awayTeamId, name: "Chelsea"),
      ]))

  viewModel.newMatch = Match(
    homeTeam: "Arsenal",
    awayTeam: "Chelsea",
    homeTeamId: homeTeamId,
    awayTeamId: awayTeamId)
  viewModel.createMatch()
  return viewModel
}

private final class MockMatchHistoryService: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {}
  func delete(id: UUID) throws {}
  func wipeAll() throws {}
}
