import SwiftUI
import RefWatchCore

// MARK: - StartMatchOptionsView
/// A reusable menu presenting the two entry points to start a match.
///
/// - Renders two large action cards:
///   - "Select Match" navigates to a list of previously saved matches.
///   - "Create Match" navigates to a configurable settings list.
/// - Accepts view-builder destinations so the caller controls navigation targets.
/// - Calls `onReset` on tap before navigating to ensure any in-progress match state
///   is cleared. This avoids leaking partially configured state between flows.
///
/// Usage:
/// ```swift
/// StartMatchOptionsView(onReset: reset) {
///   SavedMatchesListView(matches: saved, onSelectMatch: select)
/// } createDestination: {
///   MatchSettingsListView(matchViewModel: vm, onStartMatch: start)
/// }
/// ```

struct StartMatchOptionsView<SelectDestination: View, CreateDestination: View>: View {
  @Environment(\.theme) private var theme

  private let onReset: () -> Void
  private let selectDestination: () -> SelectDestination
  private let createDestination: () -> CreateDestination

  init(
    onReset: @escaping () -> Void,
    @ViewBuilder selectDestination: @escaping () -> SelectDestination,
    @ViewBuilder createDestination: @escaping () -> CreateDestination
  ) {
    self.onReset = onReset
    self.selectDestination = selectDestination
    self.createDestination = createDestination
  }

  var body: some View {
    ScrollView {
      VStack(spacing: theme.components.listVerticalSpacing) {
        NavigationLink {
          selectDestination()
        } label: {
          MenuCard(
            title: "Select Match",
            subtitle: nil,
            icon: "folder",
            tint: theme.colors.accentSecondary,
            accessoryIcon: "chevron.forward",
            minHeight: 88,
            role: .secondary
          )
        }
        .buttonStyle(.plain)
        // Reset any in-progress configuration before switching to selection flow.
        .simultaneousGesture(TapGesture().onEnded(onReset))

        NavigationLink {
          createDestination()
        } label: {
          MenuCard(
            title: "Create Match",
            subtitle: nil,
            icon: "plus.circle.fill",
            tint: theme.colors.textInverted,
            accessoryIcon: "chevron.forward",
            minHeight: 88,
            role: .positive
          )
        }
        .buttonStyle(.plain)
        // Reset to ensure a clean slate when starting a new configuration.
        .simultaneousGesture(TapGesture().onEnded(onReset))
      }
      .padding(.horizontal, theme.components.cardHorizontalPadding)
      .padding(.vertical, theme.components.listRowVerticalInset * 2)
    }
  }
}

#Preview("Start Match Options") {
  StartMatchOptionsView(onReset: {}) {
    EmptyView()
  } createDestination: {
    EmptyView()
  }
  .theme(DefaultTheme())
}
