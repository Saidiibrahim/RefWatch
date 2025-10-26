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
        // Match the visual style and sizing used in settings rows for consistency.
        optionRow(title: "Select Match", icon: "folder") {
          onSelectMatch()
        }
        .accessibilityIdentifier("selectMatchRow")

        optionRow(title: "Create Match", icon: "plus.circle.fill") {
          onCreateMatch()
        }
        .accessibilityIdentifier("createMatchRow")
      }
      .padding(.horizontal, theme.components.cardHorizontalPadding)
      .padding(.vertical, theme.components.listRowVerticalInset * 2)
    }
  }
}

private extension StartMatchOptionsView {
  /// Builds a tappable option row styled like `SettingsNavigationRow`.
  /// - Parameters:
  ///   - title: Display title for the row.
  ///   - icon: System image name shown leading the title.
  ///   - action: Callback invoked after we reset any in-flight match state.
  func optionRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button {
      // Always reset state before proceeding to a start flow to avoid
      // leaking partially configured data between navigation paths.
      onReset()
      action()
    } label: {
      ThemeCardContainer(role: .secondary, minHeight: 72) {
        HStack(spacing: theme.spacing.m) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(theme.colors.accentSecondary)

          VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
              .font(theme.typography.cardHeadline)
              .foregroundStyle(theme.colors.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          Spacer()
        }
      }
    }
    .buttonStyle(.plain)
  }
}

#Preview("Start Match Options") {
  StartMatchOptionsView(onReset: {}, onSelectMatch: {}, onCreateMatch: {})
  .theme(DefaultTheme())
}
