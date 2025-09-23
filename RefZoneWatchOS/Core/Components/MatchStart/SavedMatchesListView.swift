import SwiftUI
import RefWatchCore

// MARK: - SavedMatchesListView
/// Displays a list of previously saved matches.
///
/// - Tapping a row invokes `onSelectMatch` and then dismisses the view.
/// - Uses `ThemeCardContainer` to keep styling consistent with other menus.
/// - This component is intentionally dumb: selection logic is delegated upward
///   so that feature coordinators can decide how to transition.

struct SavedMatchesListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss

  let matches: [Match]
  /// Callback invoked when a match is selected from the list.
  let onSelectMatch: (Match) -> Void

  var body: some View {
    List {
      ForEach(matches) { match in
        Button {
          select(match)
        } label: {
          ThemeCardContainer(role: .secondary, minHeight: 72) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
              Text("\(match.homeTeam) vs \(match.awayTeam)")
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textPrimary)

              Text(summary(for: match))
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
            }
          }
        }
        .buttonStyle(.plain)
        .listRowInsets(cardRowInsets)
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .background(theme.colors.backgroundPrimary)
    .navigationTitle("Saved Matches")
  }
}

private extension SavedMatchesListView {
  // MARK: - Layout helpers
  var cardRowInsets: EdgeInsets {
    EdgeInsets(
      top: theme.components.listRowVerticalInset,
      leading: 0,
      bottom: theme.components.listRowVerticalInset,
      trailing: 0
    )
  }

  // MARK: - Formatting helpers
  func summary(for match: Match) -> String {
    let durationMinutes = Int(match.duration / 60)
    return "Duration: \(durationMinutes) min • Periods: \(match.numberOfPeriods)"
  }

  // MARK: - Actions
  func select(_ match: Match) {
    // Report selection upward and close the screen.
    onSelectMatch(match)
    dismiss()
  }
}

#Preview("Saved Matches") {
  NavigationStack {
    SavedMatchesListView(matches: [Match(homeTeam: "Leeds United", awayTeam: "Newcastle United")]) { _ in }
  }
  .theme(DefaultTheme())
}
