//
//  OnboardingPageIndicator.swift
//  RefWatchiOS
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
    HStack(spacing: self.theme.spacing.s) {
      ForEach(0..<self.total, id: \.self) { index in
        Capsule(style: .continuous)
          .fill(fillColor(for: index))
          .frame(width: width(for: index), height: 8)
          .animation(animation, value: self.currentIndex)
          .accessibilityHidden(true)
      }
    }
    .padding(.vertical, self.theme.spacing.s)
    .padding(.horizontal, self.theme.spacing.m)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(indicatorLabel))
  }
}

extension OnboardingPageIndicator {
  private var indicatorLabel: String {
    String.localizedStringWithFormat(
      NSLocalizedString(
        "welcome.carousel.position",
        value: "Slide %d of %d",
        comment: "Accessibility label announcing the current onboarding slide position"),
      self.currentIndex + 1,
      max(self.total, 1))
  }

  private var animation: Animation? {
    guard self.reduceMotion == false else { return nil }
    return .spring(response: 0.35, dampingFraction: 0.8)
  }

  private func width(for index: Int) -> CGFloat {
    index == self.currentIndex ? 24 : 8
  }

  private func fillColor(for index: Int) -> Color {
    index == self.currentIndex ? self.theme.colors.accentPrimary : self.theme.colors.outlineMuted
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
