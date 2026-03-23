//
//  LifecycleAlertOverlayView.swift
//  RefWatchWatchOS
//
//  Description: Blocking watch overlay for repeating lifecycle haptics.
//

import SwiftUI

struct LifecycleAlertOverlayView: View {
  let alert: WatchLifecycleAlert
  let onAcknowledge: () -> Void

  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  var body: some View {
    ZStack {
      Color.black.opacity(0.68)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
          // Swallow background taps so acknowledgment stays explicit.
        }

      VStack(spacing: self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14)) {
        VStack(spacing: self.layout.dimension(self.theme.spacing.s, minimum: 6, maximum: 10)) {
          Image(systemName: "bell.badge.fill")
            .font(.system(size: self.layout.dimension(24, minimum: 20, maximum: 28), weight: .semibold))
            .foregroundStyle(self.theme.colors.matchPositive)

          VStack(spacing: self.layout.dimension(self.theme.spacing.xs, minimum: 4, maximum: 8)) {
            Text(self.alert.title)
              .font(self.theme.typography.cardHeadline.weight(.semibold))
              .foregroundStyle(self.theme.colors.textPrimary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)

            Text(self.alert.message)
              .font(self.theme.typography.cardMeta)
              .foregroundStyle(self.theme.colors.textSecondary)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
          }
        }

        Button(action: self.onAcknowledge) {
          Text("Acknowledge")
            .font(self.theme.typography.cardHeadline)
            .foregroundStyle(self.theme.colors.textInverted)
            .frame(maxWidth: .infinity)
            .frame(height: self.layout.dimension(42, minimum: 38, maximum: 46))
            .background(
              RoundedRectangle(cornerRadius: self.layout.dimension(18, minimum: 16, maximum: 20), style: .continuous)
                .fill(self.theme.colors.matchPositive))
            .overlay(
              RoundedRectangle(cornerRadius: self.layout.dimension(18, minimum: 16, maximum: 20), style: .continuous)
                .stroke(self.theme.colors.matchPositive.opacity(0.72), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lifecycleAlertAcknowledgeButton")
      }
      .padding(.vertical, self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14))
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.m, minimum: 10, maximum: 14))
      .background(
        RoundedRectangle(cornerRadius: self.layout.dimension(24, minimum: 20, maximum: 28), style: .continuous)
          .fill(self.theme.colors.backgroundPrimary))
      .overlay(
        RoundedRectangle(cornerRadius: self.layout.dimension(24, minimum: 20, maximum: 28), style: .continuous)
          .stroke(self.theme.colors.outlineMuted.opacity(0.72), lineWidth: 1))
      .padding(.horizontal, self.layout.dimension(self.theme.spacing.s, minimum: 8, maximum: 12))
      .accessibilityElement(children: .contain)
      .accessibilityAddTraits(.isModal)
      .accessibilityIdentifier("lifecycleAlertOverlay")
    }
  }
}
