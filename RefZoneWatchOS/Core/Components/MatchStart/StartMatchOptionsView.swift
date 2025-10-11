import SwiftUI
import RefWatchCore

// MARK: - StartMatchOptionsView
/// A reusable menu presenting the two entry points to start a match.
///
/// - Renders two large action cards:
///   - "Select Match" navigates to a list of previously saved matches.
///   - "Create Match" navigates to a configurable settings list.
/// - Exposes callbacks for the caller to drive navigation when an option is tapped.
/// - Calls `onReset` before invoking the tap handlers to ensure any in-progress
///   match state is cleared. This avoids leaking partially configured state between flows.

struct StartMatchOptionsView: View {
  @Environment(\.theme) private var theme

  private let onReset: () -> Void
  private let onSelectMatch: () -> Void
  private let onCreateMatch: () -> Void

  init(
    onReset: @escaping () -> Void,
    onSelectMatch: @escaping () -> Void,
    onCreateMatch: @escaping () -> Void
  ) {
    self.onReset = onReset
    self.onSelectMatch = onSelectMatch
    self.onCreateMatch = onCreateMatch
  }

  var body: some View {
    ScrollView {
      VStack(spacing: theme.components.listVerticalSpacing) {
        Button {
          onReset()
          onSelectMatch()
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

        Button {
          onReset()
          onCreateMatch()
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
      }
      .padding(.horizontal, theme.components.cardHorizontalPadding)
      .padding(.vertical, theme.components.listRowVerticalInset * 2)
    }
  }
}

#Preview("Start Match Options") {
  StartMatchOptionsView(onReset: {}, onSelectMatch: {}, onCreateMatch: {})
  .theme(DefaultTheme())
}
