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

  init(
    team: TeamDetailsView.TeamType,
    matchViewModel: MatchViewModel,
    onComplete: @escaping () -> Void)
  {
    self.team = team
    self.matchViewModel = matchViewModel
    self.onComplete = onComplete
  }

  fileprivate init(
    team: TeamDetailsView.TeamType,
    matchViewModel: MatchViewModel,
    onComplete: @escaping () -> Void,
    initialPlayersOff: [SubstitutionSelection],
    initialPlayersOn: [SubstitutionSelection])
  {
    self.team = team
    self.matchViewModel = matchViewModel
    self.onComplete = onComplete
    self._playersOff = State(initialValue: initialPlayersOff)
    self._playersOn = State(initialValue: initialPlayersOn)
  }

  var body: some View {
    List {
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
    SubstitutionFlowSupport.selectionSummary(for: self.selections(for: target))
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
    SubstitutionFlowSupport.canSubmit(playersOff: self.playersOff, playersOn: self.playersOn)
  }

  private func handleDone() {
    guard self.canSubmit else { return }
    if SubstitutionFlowSupport.shouldRequireConfirmation(
      confirmSubstitutions: self.settingsViewModel.settings.confirmSubstitutions,
      pairCount: self.orderedPairs.count)
    {
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

struct SubstitutionSelection: Identifiable, Equatable, Hashable {
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

  fileprivate init(player: SubstitutionSelectablePlayer) {
    self.id = UUID()
    self.participantId = player.participantId
    self.number = player.number
    self.name = player.name.trimmedOrNil
  }

  var displayLabel: String {
    Self.formattedParticipant(number: self.number, name: self.name) ?? "Player"
  }

  var summaryLabel: String {
    self.number.map(String.init) ?? "?"
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

  init(title: String, selections: Binding<[SubstitutionSelection]>) {
    self.title = title
    self._selections = selections
  }

  fileprivate init(
    title: String,
    selections: Binding<[SubstitutionSelection]>,
    initialNumberString: String)
  {
    self.title = title
    self._selections = selections
    self._numberString = State(initialValue: initialNumberString)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: self.theme.spacing.m) {
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
          },
          onEmptyBackspace: {
            SubstitutionFlowSupport.removeMostRecentSelection(from: &self.selections)
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
    guard SubstitutionFlowSupport.appendManualSelection(number: number, to: &self.selections) else {
      return false
    }

    self.numberString = ""
    return true
  }

  private func submitCurrentNumber() {
    guard self.addCurrentNumber() else { return }
    guard self.selections.isEmpty == false else { return }
    self.dismiss()
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

enum SubstitutionFlowSupport {
  static func selectionSummary(
    for selections: [SubstitutionSelection],
    emptyText: String = "Select player") -> String
  {
    guard selections.isEmpty == false else { return emptyText }
    return selections.map(\.summaryLabel).joined(separator: ", ")
  }

  static func canSubmit(
    playersOff: [SubstitutionSelection],
    playersOn: [SubstitutionSelection]) -> Bool
  {
    playersOff.isEmpty == false && playersOff.count == playersOn.count
  }

  static func shouldRequireConfirmation(
    confirmSubstitutions: Bool,
    pairCount: Int) -> Bool
  {
    confirmSubstitutions && pairCount == 1
  }

  @discardableResult
  static func appendManualSelection(
    number: Int,
    to selections: inout [SubstitutionSelection]) -> Bool
  {
    guard number > 0 else { return false }
    guard selections.contains(where: { $0.number == number }) == false else { return false }
    selections.append(SubstitutionSelection(number: number, name: nil))
    return true
  }

  static func removeMostRecentSelection(from selections: inout [SubstitutionSelection]) {
    guard selections.isEmpty == false else { return }
    selections.removeLast()
  }
}

// MARK: - Preview Support

#Preview("Sub Hub – Legacy Empty") {
  previewNavigationHost(
    layout: WatchLayoutScale(category: .standard),
    settingsViewModel: SubstitutionFlowPreviewFixtures.settingsViewModel())
  {
    SubstitutionFlow(
      team: .home,
      matchViewModel: SubstitutionFlowPreviewFixtures.makeMatchViewModel(for: .legacyRoster),
      onComplete: {})
  }
}

#Preview("Sub Hub – Mismatch") {
  previewNavigationHost(
    layout: WatchLayoutScale(category: .standard),
    settingsViewModel: SubstitutionFlowPreviewFixtures.settingsViewModel())
  {
    SubstitutionFlow(
      team: .home,
      matchViewModel: SubstitutionFlowPreviewFixtures.makeMatchViewModel(for: .manualOnly),
      onComplete: {},
      initialPlayersOff: SubstitutionFlowPreviewFixtures.readyOffSelections,
      initialPlayersOn: [SubstitutionFlowPreviewFixtures.readyOnSelections[0]])
  }
}

#Preview("Sub Hub – Ready To Confirm") {
  previewNavigationHost(
    layout: WatchLayoutScale(category: .standard),
    settingsViewModel: SubstitutionFlowPreviewFixtures.settingsViewModel(confirmSubstitutions: true))
  {
    SubstitutionFlow(
      team: .home,
      matchViewModel: SubstitutionFlowPreviewFixtures.makeMatchViewModel(for: .readySheets),
      onComplete: {},
      initialPlayersOff: [SubstitutionFlowPreviewFixtures.readyOffSelections[0]],
      initialPlayersOn: [SubstitutionFlowPreviewFixtures.readyOnSelections[0]])
  }
}

#Preview("Sub Hub – Ready To Save") {
  previewNavigationHost(
    layout: WatchLayoutScale(category: .standard),
    settingsViewModel: SubstitutionFlowPreviewFixtures.settingsViewModel(confirmSubstitutions: true))
  {
    SubstitutionFlow(
      team: .home,
      matchViewModel: SubstitutionFlowPreviewFixtures.makeMatchViewModel(for: .readySheets),
      onComplete: {},
      initialPlayersOff: SubstitutionFlowPreviewFixtures.readyOffSelections,
      initialPlayersOn: SubstitutionFlowPreviewFixtures.readyOnSelections)
  }
}

#Preview("Sub Off – Ready Sheet") {
  @Previewable @State var selections = SubstitutionFlowPreviewFixtures.readyOffSelections

  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionPlayerSelectionView(
      title: SubstitutionTarget.playerOff.title,
      players: SubstitutionFlowPreviewFixtures.readyOffPlayers,
      selections: $selections)
  }
}

#Preview("Sub On – Ready Sheet") {
  @Previewable @State var selections = SubstitutionFlowPreviewFixtures.readyOnSelections

  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionPlayerSelectionView(
      title: SubstitutionTarget.playerOn.title,
      players: SubstitutionFlowPreviewFixtures.readyOnPlayers,
      selections: $selections)
  }
}

#Preview("Sub Off – Ready Sheet – 41mm") {
  @Previewable @State var selections = [SubstitutionFlowPreviewFixtures.readyOffSelections[0]]

  previewNavigationHost(layout: WatchLayoutScale(category: .compact)) {
    SubstitutionPlayerSelectionView(
      title: SubstitutionTarget.playerOff.title,
      players: SubstitutionFlowPreviewFixtures.readyOffPlayers,
      selections: $selections)
  }
}

#Preview("Sub Manual – Empty") {
  @Previewable @State var selections: [SubstitutionSelection] = []

  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionNumberCollectorView(
      title: SubstitutionTarget.playerOn.title,
      selections: $selections)
  }
}

#Preview("Sub Manual – Typing") {
  @Previewable @State var selections = SubstitutionFlowPreviewFixtures.manualSelections

  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionNumberCollectorView(
      title: SubstitutionTarget.playerOn.title,
      selections: $selections,
      initialNumberString: "16")
  }
}

#Preview("Sub Manual – Filled – 41mm") {
  @Previewable @State var selections = SubstitutionFlowPreviewFixtures.manualSelections

  previewNavigationHost(layout: WatchLayoutScale(category: .compact)) {
    SubstitutionNumberCollectorView(
      title: SubstitutionTarget.playerOn.title,
      selections: $selections,
      initialNumberString: "")
  }
}

#Preview("Sub Hub – Manual Ready") {
  previewNavigationHost(
    layout: WatchLayoutScale(category: .standard),
    settingsViewModel: SubstitutionFlowPreviewFixtures.settingsViewModel(confirmSubstitutions: true))
  {
    SubstitutionFlow(
      team: .home,
      matchViewModel: SubstitutionFlowPreviewFixtures.makeMatchViewModel(for: .manualOnly),
      onComplete: {},
      initialPlayersOff: SubstitutionFlowPreviewFixtures.manualSelections,
      initialPlayersOn: SubstitutionFlowPreviewFixtures.manualOnSelections)
  }
}

#Preview("Sub Blocked – Off") {
  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionUnavailableView(
      title: SubstitutionTarget.playerOff.title,
      message: SubstitutionFlowPreviewFixtures.unavailableMessage(for: .playerOff))
  }
}

#Preview("Sub Blocked – On") {
  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionUnavailableView(
      title: SubstitutionTarget.playerOn.title,
      message: SubstitutionFlowPreviewFixtures.unavailableMessage(for: .playerOn))
  }
}

#Preview("Sub Confirm – Single Pair") {
  previewNavigationHost(layout: WatchLayoutScale(category: .standard)) {
    SubstitutionBatchConfirmationView(
      pairs: [SubstitutionFlowPreviewFixtures.confirmationPairs[0]],
      matchTime: SubstitutionFlowPreviewFixtures.confirmationSnapshot.matchTime,
      onConfirm: {})
  }
}

@MainActor
private enum SubstitutionFlowPreviewFixtures {
  enum Scenario {
    case legacyRoster
    case readySheets
    case manualOnly
  }

  static let homeTeamID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
  static let awayTeamID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

  static let readyStarterEntries: [MatchSheetPlayerEntry] = [
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
      displayName: "Alexandria Johnson-Smith",
      shirtNumber: 2,
      position: "RB",
      sortOrder: 1),
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
      displayName: "Priya Bennett",
      shirtNumber: 6,
      position: "CM",
      sortOrder: 2),
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
      displayName: "Charlotte de la Cruz",
      shirtNumber: 8,
      position: "AM",
      sortOrder: 3),
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
      displayName: "Mia Torres",
      shirtNumber: 11,
      position: "FW",
      sortOrder: 4),
  ]

  static let readySubstituteEntries: [MatchSheetPlayerEntry] = [
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000011")!,
      displayName: "Eleanor Whitmore",
      shirtNumber: 12,
      position: "WB",
      sortOrder: 5),
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000012")!,
      displayName: "Sofia Martinez",
      shirtNumber: 16,
      position: "CM",
      sortOrder: 6),
    MatchSheetPlayerEntry(
      entryId: UUID(uuidString: "30000000-0000-0000-0000-000000000013")!,
      displayName: "Harper-Louise Andersen",
      shirtNumber: 18,
      position: "FW",
      sortOrder: 7),
  ]

  static let awayStarterEntries: [MatchSheetPlayerEntry] = [
    MatchSheetPlayerEntry(displayName: "Away Starter One", shirtNumber: 4, sortOrder: 1),
    MatchSheetPlayerEntry(displayName: "Away Starter Two", shirtNumber: 5, sortOrder: 2),
  ]

  static let awaySubstituteEntries: [MatchSheetPlayerEntry] = [
    MatchSheetPlayerEntry(displayName: "Away Sub One", shirtNumber: 14, sortOrder: 3),
    MatchSheetPlayerEntry(displayName: "Away Sub Two", shirtNumber: 15, sortOrder: 4),
  ]

  static let legacyPlayers: [MatchLibraryPlayer] = [
    MatchLibraryPlayer(id: UUID(), name: "Bob Smith", number: 1),
    MatchLibraryPlayer(id: UUID(), name: "James Woods", number: 2),
    MatchLibraryPlayer(id: UUID(), name: "Mike Robson", number: 3),
    MatchLibraryPlayer(id: UUID(), name: "Oliver Keeble", number: 4),
  ]

  static let readyOffPlayers = Self.readyStarterEntries.map(SubstitutionSelectablePlayer.init(entry:))
  static let readyOnPlayers = Self.readySubstituteEntries.map(SubstitutionSelectablePlayer.init(entry:))

  static let readyOffSelections: [SubstitutionSelection] = [
    Self.selection(from: Self.readyOffPlayers[0]),
    Self.selection(from: Self.readyOffPlayers[2]),
  ]

  static let readyOnSelections: [SubstitutionSelection] = [
    Self.selection(from: Self.readyOnPlayers[0]),
    Self.selection(from: Self.readyOnPlayers[1]),
  ]

  static let manualSelections: [SubstitutionSelection] = [
    SubstitutionSelection(
      id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
      participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000011")!,
      number: 12),
    SubstitutionSelection(
      id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
      participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000012")!,
      number: 16),
  ]

  static let manualOnSelections: [SubstitutionSelection] = [
    SubstitutionSelection(
      id: UUID(uuidString: "40000000-0000-0000-0000-000000000013")!,
      participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000014")!,
      number: 14),
    SubstitutionSelection(
      id: UUID(uuidString: "40000000-0000-0000-0000-000000000015")!,
      participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000016")!,
      number: 18),
  ]

  static let confirmationPairs: [SubstitutionPair] = [
    SubstitutionPair(playerOff: Self.readyOffSelections[0], playerOn: Self.readyOnSelections[0]),
    SubstitutionPair(playerOff: Self.readyOffSelections[1], playerOn: Self.readyOnSelections[1]),
    SubstitutionPair(
      playerOff: SubstitutionSelection(
        participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000021")!,
        number: 11,
        name: "Mia Torres"),
      playerOn: SubstitutionSelection(
        participantId: UUID(uuidString: "40000000-0000-0000-0000-000000000022")!,
        number: 18,
        name: "Harper-Louise Andersen")),
  ]

  static let confirmationSnapshot = MatchViewModel.EventSnapshot(
    timestamp: Date(timeIntervalSince1970: 1_742_000_500),
    matchTime: "67:42",
    period: 2)

  static func settingsViewModel(confirmSubstitutions: Bool = true) -> SettingsViewModel {
    let viewModel = SettingsViewModel()
    viewModel.settings.confirmSubstitutions = confirmSubstitutions
    return viewModel
  }

  static func unavailableMessage(for target: SubstitutionTarget) -> String {
    switch target {
    case .playerOff:
      return "No eligible on-field players remain on the official match sheet."
    case .playerOn:
      return "No unused substitutes remain on the official match sheet."
    }
  }

  static func makeMatchViewModel(for scenario: Scenario) -> MatchViewModel {
    let viewModel = MatchViewModel(
      history: MockMatchHistoryService(),
      haptics: NoopHaptics())

    viewModel.updateLibrary(
      with: MatchLibrarySnapshot(
        teams: [
          MatchLibraryTeam(
            id: Self.homeTeamID,
            name: "Arsenal",
            players: Self.legacyPlayers),
          MatchLibraryTeam(id: Self.awayTeamID, name: "Chelsea"),
        ]))

    viewModel.newMatch = Self.match(for: scenario)
    viewModel.createMatch()
    viewModel.matchTime = Self.confirmationSnapshot.matchTime
    viewModel.currentPeriod = Self.confirmationSnapshot.period
    return viewModel
  }

  private static func match(for scenario: Scenario) -> Match {
    switch scenario {
    case .legacyRoster:
      return Match(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeTeamId: Self.homeTeamID,
        awayTeamId: Self.awayTeamID)
    case .readySheets:
      return Match(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeTeamId: Self.homeTeamID,
        awayTeamId: Self.awayTeamID,
        homeMatchSheet: Self.readyHomeSheet,
        awayMatchSheet: Self.readyAwaySheet)
    case .manualOnly:
      return Match(
        homeTeam: "Arsenal",
        awayTeam: "Chelsea",
        homeTeamId: Self.homeTeamID,
        awayTeamId: Self.awayTeamID,
        homeMatchSheet: Self.draftHomeSheet,
        awayMatchSheet: nil)
    }
  }

  private static var readyHomeSheet: ScheduledMatchSheet {
    ScheduledMatchSheet(
      sourceTeamId: Self.homeTeamID,
      sourceTeamName: "Arsenal",
      status: .ready,
      starters: Self.readyStarterEntries,
      substitutes: Self.readySubstituteEntries,
      updatedAt: Date(timeIntervalSince1970: 1_742_000_300))
  }

  private static var readyAwaySheet: ScheduledMatchSheet {
    ScheduledMatchSheet(
      sourceTeamId: Self.awayTeamID,
      sourceTeamName: "Chelsea",
      status: .ready,
      starters: Self.awayStarterEntries,
      substitutes: Self.awaySubstituteEntries,
      updatedAt: Date(timeIntervalSince1970: 1_742_000_320))
  }

  private static var draftHomeSheet: ScheduledMatchSheet {
    ScheduledMatchSheet(
      sourceTeamId: Self.homeTeamID,
      sourceTeamName: "Arsenal",
      status: .draft,
      starters: [
        MatchSheetPlayerEntry(displayName: "Draft Starter", shirtNumber: 9, sortOrder: 1),
      ],
      updatedAt: Date(timeIntervalSince1970: 1_742_000_400))
  }

  private static func selection(from player: SubstitutionSelectablePlayer) -> SubstitutionSelection {
    SubstitutionSelection(
      participantId: player.participantId,
      number: player.number,
      name: player.name)
  }
}

private final class MockMatchHistoryService: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {}
  func delete(id: UUID) throws {}
  func wipeAll() throws {}
}

private func previewNavigationHost<Content: View>(
  layout: WatchLayoutScale,
  settingsViewModel: SettingsViewModel? = nil,
  @ViewBuilder content: () -> Content) -> some View
{
  NavigationStack {
    content()
  }
  .theme(DefaultTheme())
  .watchLayoutScale(layout)
  .previewSettings(settingsViewModel)
}

private extension View {
  @ViewBuilder
  func previewSettings(_ settingsViewModel: SettingsViewModel?) -> some View {
    if let settingsViewModel {
      self.environment(settingsViewModel)
    } else {
      self
    }
  }
}
