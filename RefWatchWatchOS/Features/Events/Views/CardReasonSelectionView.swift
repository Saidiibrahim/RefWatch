import SwiftUI
import RefWatchCore

struct CardReasonSelectionView: View {
  let cardType: CardDetails.CardType
  let isTeamOfficial: Bool
  let onSelect: (String) -> Void
  @Environment(SettingsViewModel.self) private var settingsViewModel

  var body: some View {
    if reasons.isEmpty {
      EmptyStateView(title: title)
    } else {
      SelectionListView(
        title: title,
        options: reasons,
        formatter: { $0.displayText },
        onSelect: { reason in
          onSelect(reason.displayText)
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
