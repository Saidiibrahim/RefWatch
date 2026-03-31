//
//  PlayerNumberInputView.swift
//  RefWatchWatchOS
//
//  Player selector that prefers saved/library participant lists and falls back
//  to numeric entry when no side-specific player list is available.
//

import RefWatchCore
import SwiftUI

struct PlayerSelectionResult: Equatable, Hashable {
  let number: Int?
  let name: String?
}

struct PlayerSelectionOption: Identifiable, Equatable, Hashable {
  let participantId: UUID
  let number: Int?
  let name: String?
  let position: String?
  let notes: String?

  var id: UUID { self.participantId }

  init(
    participantId: UUID,
    number: Int?,
    name: String?,
    position: String? = nil,
    notes: String? = nil)
  {
    self.participantId = participantId
    self.number = number
    self.name = name?.trimmedOrNil
    self.position = position
    self.notes = notes
  }

  init(player: MatchSelectablePlayer) {
    self.init(
      participantId: player.participantId,
      number: player.shirtNumber,
      name: player.displayName,
      position: player.position,
      notes: player.notes)
  }

  init(player: MatchLibraryPlayer) {
    self.init(
      participantId: player.id,
      number: player.number,
      name: player.name,
      position: player.position,
      notes: player.notes)
  }

  init(entry: MatchSheetPlayerEntry) {
    self.init(
      participantId: entry.entryId,
      number: entry.shirtNumber,
      name: entry.displayName,
      position: entry.position,
      notes: entry.notes)
  }

  var displayLabel: String {
    let trimmedName = self.name?.trimmedOrNil
    switch (self.number, trimmedName) {
    case let (number?, name?):
      return "#\(number) \(name)"
    case let (number?, nil):
      return "#\(number)"
    case let (nil, name?):
      return "#? \(name)"
    case (nil, nil):
      return "Player"
    }
  }

  var selection: PlayerSelectionResult {
    PlayerSelectionResult(number: self.number, name: self.name)
  }
}

struct PlayerNumberInputView: View {
  let title: String
  let selectionOptions: [PlayerSelectionOption]
  let placeholder: String
  let onComplete: (PlayerSelectionResult) -> Void

  @State private var numberString = ""

  init(
    title: String,
    selectionOptions: [PlayerSelectionOption] = [],
    placeholder: String,
    onComplete: @escaping (PlayerSelectionResult) -> Void)
  {
    self.title = title
    self.selectionOptions = selectionOptions
    self.placeholder = placeholder
    self.onComplete = onComplete
  }

  var body: some View {
    Group {
      if self.selectionOptions.isEmpty {
        VStack(spacing: 12) {
          NumericKeypad(
            numberString: self.$numberString,
            maxDigits: 2,
            placeholder: self.placeholder,
            placeholderColor: .gray)
          {
            guard let number = Int(self.numberString), number > 0 else { return }
            self.onComplete(PlayerSelectionResult(number: number, name: nil))
          }
        }
      } else {
        SelectionListView(
          title: self.title,
          options: self.selectionOptions,
          formatter: { $0.displayLabel },
          onSelect: { option in
            self.onComplete(option.selection)
          })
      }
    }
    .navigationTitle(self.title)
  }
}

private extension String {
  var trimmedOrNil: String? {
    let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
