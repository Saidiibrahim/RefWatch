import SwiftUI
import Observation
import RefWatchCore

// MARK: - MatchSettingsListView
/// A reusable list for configuring a new match before kickoff.
///
/// - Presents duration, number of periods, and half-time length as navigable pickers.
/// - Optional sections appear when toggles are enabled (Extra Time, Penalties).
/// - Calls `onStartMatch` with the bound `MatchViewModel` and dismisses when the
///   user taps the "Start Match" primary action.
///
/// The view owns no lifecycle routing; callers decide what happens after starting.

struct MatchSettingsListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Bindable var matchViewModel: MatchViewModel

  /// Callback invoked when the user confirms and starts the match.
  /// The provided `MatchViewModel` contains the configured settings.
  let onStartMatch: (MatchViewModel) -> Void

  /// Label for the primary action button. Defaults to "Start Match".
  let primaryActionLabel: String

  /// Toggles the visibility of the primary action row.
  let showsPrimaryAction: Bool

  init(
    matchViewModel: MatchViewModel,
    primaryActionLabel: String = "Start Match",
    showsPrimaryAction: Bool = true,
    onStartMatch: @escaping (MatchViewModel) -> Void
  ) {
    self._matchViewModel = Bindable(matchViewModel)
    self.primaryActionLabel = primaryActionLabel
    self.showsPrimaryAction = showsPrimaryAction
    self.onStartMatch = onStartMatch
  }

  var body: some View {
    List {
      // Base match structure
      Section {
        durationRow
        periodsRow
        halfTimeRow
      }

      // Global options toggles
      Section {
        SettingsToggleRow(
          title: "Extra Time",
          subtitle: nil,
          icon: "clock.badge.plus",
          isOn: $matchViewModel.hasExtraTime
        )
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)

        SettingsToggleRow(
          title: "Penalties",
          subtitle: nil,
          icon: "soccerball",
          isOn: $matchViewModel.hasPenalties
        )
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
      }

      // Extra Time configuration appears only when enabled
      if matchViewModel.hasExtraTime {
        Section {
          extraTimeRow
        }
      }

      // Penalty shootout configuration appears only when enabled
      if matchViewModel.hasPenalties {
        Section {
          shootoutRow
        }
      }

      // Primary action: start match with the configured settings
      if showsPrimaryAction {
        Section {
          ThemeCardContainer(role: .positive, minHeight: 80) {
            Button {
              startMatch()
            } label: {
              HStack(spacing: theme.spacing.m) {
                Image(systemName: "play.circle.fill")
                  .font(theme.typography.iconAccent)
                  .foregroundStyle(theme.colors.textInverted)

                Text(primaryActionLabel)
                  .font(theme.typography.cardHeadline)
                  .foregroundStyle(theme.colors.textInverted)

                Spacer()
              }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("startMatchButton")
          }
          .listRowInsets(cardRowInsets)
          .listRowBackground(Color.clear)
        }
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .background(theme.colors.backgroundPrimary)
    .navigationTitle("Match Settings")
  }
}

private extension MatchSettingsListView {
  // MARK: - Rows
  var durationRow: some View {
    NavigationLink {
      SettingPickerView(
        title: "Duration",
        values: [40, 45, 50],
        selection: $matchViewModel.matchDuration,
        formatter: { "\($0) min" }
      )
    } label: {
      SettingsNavigationRow(
        title: "Duration",
        value: "\(matchViewModel.matchDuration) min",
        icon: "clock",
        valueIdentifier: nil
      )
    }
    .listRowInsets(cardRowInsets)
    .listRowBackground(Color.clear)
  }

  var periodsRow: some View {
    NavigationLink {
      SettingPickerView(
        title: "Periods",
        values: [1, 2, 3, 4],
        selection: $matchViewModel.numberOfPeriods,
        formatter: String.init
      )
    } label: {
      SettingsNavigationRow(
        title: "Periods",
        value: "\(matchViewModel.numberOfPeriods)",
        icon: "square.grid.2x2",
        valueIdentifier: nil
      )
    }
    .listRowInsets(cardRowInsets)
    .listRowBackground(Color.clear)
  }

  var halfTimeRow: some View {
    NavigationLink {
      SettingPickerView(
        title: "Half-time",
        values: [10, 15, 20],
        selection: $matchViewModel.halfTimeLength,
        formatter: { "\($0) min" }
      )
    } label: {
      SettingsNavigationRow(
        title: "HT Length",
        value: "\(matchViewModel.halfTimeLength) min",
        icon: "hourglass.bottomhalf",
        valueIdentifier: nil
      )
    }
    .listRowInsets(cardRowInsets)
    .listRowBackground(Color.clear)
  }

  var extraTimeRow: some View {
    NavigationLink {
      SettingPickerView(
        title: "ET Half Length",
        values: [5, 10, 15, 20, 30],
        selection: $matchViewModel.extraTimeHalfLengthMinutes,
        formatter: { "\($0) min" }
      )
    } label: {
      SettingsNavigationRow(
        title: "ET Half Length",
        value: "\(matchViewModel.extraTimeHalfLengthMinutes) min",
        icon: "stopwatch",
        valueIdentifier: nil
      )
    }
    .listRowInsets(cardRowInsets)
    .listRowBackground(Color.clear)
  }

  var shootoutRow: some View {
    NavigationLink {
      SettingPickerView(
        title: "Shootout Rounds",
        values: [3, 5, 7, 10],
        selection: $matchViewModel.penaltyInitialRounds,
        formatter: { String($0) }
      )
    } label: {
      SettingsNavigationRow(
        title: "Shootout Rounds",
        value: "\(matchViewModel.penaltyInitialRounds)",
        icon: "soccerball",
        valueIdentifier: nil
      )
    }
    .listRowInsets(cardRowInsets)
    .listRowBackground(Color.clear)
  }

  // MARK: - Actions
  func startMatch() {
    // Propagate the configured model upstream and close the screen.
    onStartMatch(matchViewModel)
    dismiss()
  }

  var cardRowInsets: EdgeInsets {
    EdgeInsets(
      top: theme.components.listRowVerticalInset,
      leading: 0,
      bottom: theme.components.listRowVerticalInset,
      trailing: 0
    )
  }
}

#Preview("Match Settings") {
  NavigationStack {
    MatchSettingsListView(matchViewModel: MatchViewModel(haptics: WatchHaptics())) { _ in }
  }
  .theme(DefaultTheme())
}
