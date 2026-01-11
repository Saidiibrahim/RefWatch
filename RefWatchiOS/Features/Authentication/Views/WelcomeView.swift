//
//  WelcomeView.swift
//  RefWatchiOS
//
//  Introduces the app during the onboarding/authentication flow.
//

import RefWatchCore
import SwiftUI

/// Centralized color helper for WelcomeView that adapts to light/dark mode
struct WelcomeColors {
  let background: Color
  let secondaryButtonTint: Color
  let privacyNoteText: Color

  init(theme: AnyTheme, colorScheme: ColorScheme) {
    let accentPrimary = theme.colors.accentPrimary

    switch colorScheme {
    case .dark:
      // Preserve existing dark mode behavior
      self.background = theme.colors.backgroundPrimary
      self.secondaryButtonTint = theme.colors.textSecondary.opacity(0.9)
      self.privacyNoteText = theme.colors.textSecondary.opacity(0.86)

    default: // .light
      // New minimal, clean light mode
      self.background = Color(uiColor: .systemBackground)
      self.secondaryButtonTint = accentPrimary
      self.privacyNoteText = Color(uiColor: .secondaryLabel).opacity(0.75)
    }
  }
}

/// A focused welcome experience that highlights key RefWatch touchpoints before sign-in.
struct WelcomeView: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator
  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @State private var currentSlideIndex = 0

  private var slides: [WelcomeSlide] {
    WelcomeSlide.defaultSlides(theme: self.theme)
  }

  var body: some View {
    ZStack {
      colors.background.ignoresSafeArea()

      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: self.theme.spacing.stackXL) {
          carousel
          OnboardingPageIndicator(total: self.slides.count, currentIndex: self.currentSlideIndex)
          primaryActions
          privacyNote
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, self.theme.spacing.stackXL)
        .frame(maxWidth: .infinity)
      }
    }
    .onChange(of: self.slides.count) { _, newCount in
      self.currentSlideIndex = min(self.currentSlideIndex, max(newCount - 1, 0))
    }
  }
}

extension WelcomeView {
  fileprivate var colors: WelcomeColors {
    WelcomeColors(theme: self.theme, colorScheme: self.colorScheme)
  }

  private var horizontalPadding: CGFloat {
    self.dynamicTypeSize.isAccessibilitySize ? self.theme.spacing.stackXL : self.theme.spacing.stackXL * CGFloat(1.5)
  }

  private var carousel: some View {
    TabView(selection: self.$currentSlideIndex) {
      ForEach(Array(self.slides.enumerated()), id: \.element.id) { index, slide in
        OnboardingCardView(slide: slide)
          .padding(.horizontal, self.theme.spacing.stackSM)
          .tag(index)
          .accessibilityAddTraits(index == self.currentSlideIndex ? .isSelected : [])
      }
    }
    .frame(height: self.cardHeight)
    .tabViewStyle(.page(indexDisplayMode: .never))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(self.slides[safe: self.currentSlideIndex]?.title ?? ""))
    .accessibilityHint(Text(self.slides[safe: self.currentSlideIndex]?.subtitle ?? ""))
  }

  private var primaryActions: some View {
    VStack(spacing: 10) {
      Button {
        self.coordinator.showSignIn()
      } label: {
        Text(NSLocalizedString(
          "welcome.actions.signIn",
          value: "Sign In",
          comment: "Primary CTA to sign in from the welcome carousel"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(self.theme.colors.accentSecondary)
      .accessibilityHint(Text(NSLocalizedString(
        "welcome.actions.signIn.hint",
        value: "Opens the sign-in form",
        comment: "Accessibility hint for sign-in button")))

      Button {
        self.coordinator.showSignUp()
      } label: {
        Text(NSLocalizedString(
          "welcome.actions.createAccount",
          value: "Create Account",
          comment: "Secondary CTA to create a new RefWatch account"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(self.colors.secondaryButtonTint)
      .accessibilityHint(Text(NSLocalizedString(
        "welcome.actions.createAccount.hint",
        value: "Opens the account creation form",
        comment: "Accessibility hint for create account button")))
    }
  }

  private var privacyNote: some View {
    Text(NSLocalizedString(
      "welcome.privacyNote",
      value: "An active RefWatch account is required on iPhone. " +
        "Your Apple Watch can still log matches offline and will sync once you sign in here.",
      comment: "Footer note explaining onboarding requirements"))
      .font(self.theme.typography.caption)
      .foregroundStyle(self.colors.privacyNoteText)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .frame(maxWidth: 360)
      .accessibilityHint(Text(NSLocalizedString(
        "welcome.privacyNote.hint",
        value: "Explains why signing in is required on iPhone",
        comment: "Accessibility hint for the welcome privacy note")))
  }

  private var cardHeight: CGFloat {
    self.dynamicTypeSize.isAccessibilitySize ? 480 : 420
  }
}

extension Collection {
  fileprivate subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

#if DEBUG
#Preview {
  WelcomeView()
    .environmentObject(AuthenticationCoordinator(authController: SupabaseAuthController(
      clientProvider: SupabaseClientProvider.shared)))
    .theme(DefaultTheme())
}
#endif
