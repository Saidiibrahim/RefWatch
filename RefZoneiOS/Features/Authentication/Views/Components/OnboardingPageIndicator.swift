//
//  OnboardingPageIndicator.swift
//  RefZoneiOS
//
//  Displays themed dot indicators for the onboarding carousel.
//

import RefWatchCore
import SwiftUI

struct OnboardingPageIndicator: View {
  let total: Int
  let currentIndex: Int

  @Environment(\.theme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: theme.spacing.s) {
      ForEach(0..<total, id: \.self) { index in
        Capsule(style: .continuous)
          .fill(fillColor(for: index))
          .frame(width: width(for: index), height: 8)
          .animation(animation, value: currentIndex)
          .accessibilityHidden(true)
      }
    }
    .padding(.vertical, theme.spacing.s)
    .padding(.horizontal, theme.spacing.m)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(indicatorLabel))
  }
}

private extension OnboardingPageIndicator {
  var indicatorLabel: String {
    String.localizedStringWithFormat(
      NSLocalizedString("welcome.carousel.position", value: "Slide %d of %d", comment: "Accessibility label announcing the current onboarding slide position"),
      currentIndex + 1,
      max(total, 1)
    )
  }

  var animation: Animation? {
    guard reduceMotion == false else { return nil }
    return .spring(response: 0.35, dampingFraction: 0.8)
  }

  func width(for index: Int) -> CGFloat {
    index == currentIndex ? 24 : 8
  }

  func fillColor(for index: Int) -> Color {
    index == currentIndex ? theme.colors.accentPrimary : theme.colors.outlineMuted
  }
}

#if DEBUG
#Preview {
  VStack(spacing: 16) {
    OnboardingPageIndicator(total: 3, currentIndex: 0)
    OnboardingPageIndicator(total: 3, currentIndex: 1)
    OnboardingPageIndicator(total: 3, currentIndex: 2)
  }
  .padding()
  .theme(DefaultTheme())
  .background(DefaultTheme().colors.backgroundPrimary.ignoresSafeArea())
}
#endif
