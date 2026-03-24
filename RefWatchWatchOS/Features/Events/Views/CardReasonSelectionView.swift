import SwiftUI
import RefWatchCore

struct CardReasonSelectionView: View {
  let cardType: CardDetails.CardType
  let isTeamOfficial: Bool
  let onSelect: (MisconductReason) -> Void
  @Environment(SettingsViewModel.self) private var settingsViewModel

  private var accentColor: Color {
    cardType == .yellow ? .yellow : .red
  }

  var body: some View {
    if reasons.isEmpty {
      EmptyStateView(title: title)
    } else {
      SelectionListView(
        title: title,
        options: reasons,
        formatter: { $0.displayText },
        accentColor: accentColor,
        onSelect: { reason in
          onSelect(reason)
        }
      )
    }
  }
}

private extension CardReasonSelectionView {
  var title: String {
    cardType == .yellow ? "Yellow Card Reason" : "Red Card Reason"
  }

  var reasons: [MisconductReason] {
    let recipient: CardRecipientType = isTeamOfficial ? .teamOfficial : .player
    return settingsViewModel
      .activeMisconductTemplate
      .reasons(for: cardType, recipient: recipient)
  }
}

private struct EmptyStateView: View {
  @Environment(\.theme) private var theme

  let title: String

  var body: some View {
    VStack(spacing: theme.spacing.m) {
      Text("No reasons available")
        .font(theme.typography.cardHeadline)
        .foregroundStyle(theme.colors.textPrimary)

      Text("Update the configuration to continue")
        .font(theme.typography.cardMeta)
        .foregroundStyle(theme.colors.textSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, theme.components.cardHorizontalPadding)
    .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    .navigationTitle(title)
  }
}

// MARK: - Previews

#Preview("Yellow Card – Player") {
  CardReasonSelectionView(
    cardType: .yellow,
    isTeamOfficial: false,
    onSelect: { reason in print("Selected: \(reason.displayText)") }
  )
  .environment(SettingsViewModel())
}

#Preview("Red Card – Player") {
  CardReasonSelectionView(
    cardType: .red,
    isTeamOfficial: false,
    onSelect: { reason in print("Selected: \(reason.displayText)") }
  )
  .environment(SettingsViewModel())
}

#Preview("Yellow Card – Team Official") {
  CardReasonSelectionView(
    cardType: .yellow,
    isTeamOfficial: true,
    onSelect: { reason in print("Selected: \(reason.displayText)") }
  )
  .environment(SettingsViewModel())
}

#Preview("Red Card – Team Official") {
  CardReasonSelectionView(
    cardType: .red,
    isTeamOfficial: true,
    onSelect: { reason in print("Selected: \(reason.displayText)") }
  )
  .environment(SettingsViewModel())
}
