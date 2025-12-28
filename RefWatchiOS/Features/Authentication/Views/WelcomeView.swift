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
            background = theme.colors.backgroundPrimary
            secondaryButtonTint = theme.colors.textSecondary.opacity(0.9)
            privacyNoteText = theme.colors.textSecondary.opacity(0.86)

        default: // .light
            // New minimal, clean light mode
            background = Color(uiColor: .systemBackground)
            secondaryButtonTint = accentPrimary
            privacyNoteText = Color(uiColor: .secondaryLabel).opacity(0.75)
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
    WelcomeSlide.defaultSlides(theme: theme)
  }

  var body: some View {
    ZStack {
      colors.background.ignoresSafeArea()

      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: theme.spacing.stackXL) {
          carousel
          OnboardingPageIndicator(total: slides.count, currentIndex: currentSlideIndex)
          primaryActions
          privacyNote
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, theme.spacing.stackXL)
        .frame(maxWidth: .infinity)
      }
    }
    .onChange(of: slides.count) { _, newCount in
      currentSlideIndex = min(currentSlideIndex, max(newCount - 1, 0))
    }
  }
}

private extension WelcomeView {
  var colors: WelcomeColors {
    WelcomeColors(theme: theme, colorScheme: colorScheme)
  }

  var horizontalPadding: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? theme.spacing.stackXL : theme.spacing.stackXL * CGFloat(1.5)
  }

  var carousel: some View {
    TabView(selection: $currentSlideIndex) {
      ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
        OnboardingCardView(slide: slide)
          .padding(.horizontal, theme.spacing.stackSM)
          .tag(index)
          .accessibilityAddTraits(index == currentSlideIndex ? .isSelected : [])
      }
    }
    .frame(height: cardHeight)
    .tabViewStyle(.page(indexDisplayMode: .never))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(slides[safe: currentSlideIndex]?.title ?? ""))
    .accessibilityHint(Text(slides[safe: currentSlideIndex]?.subtitle ?? ""))
  }

  var primaryActions: some View {
    VStack(spacing: 10) {
      Button {
        coordinator.showSignIn()
      } label: {
        Text(NSLocalizedString("welcome.actions.signIn", value: "Sign In", comment: "Primary CTA to sign in from the welcome carousel"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(theme.colors.accentSecondary)
      .accessibilityHint(Text(NSLocalizedString("welcome.actions.signIn.hint", value: "Opens the sign-in form", comment: "Accessibility hint for sign-in button")))

      Button {
        coordinator.showSignUp()
      } label: {
        Text(NSLocalizedString("welcome.actions.createAccount", value: "Create Account", comment: "Secondary CTA to create a new RefWatch account"))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(colors.secondaryButtonTint)
      .accessibilityHint(Text(NSLocalizedString("welcome.actions.createAccount.hint", value: "Opens the account creation form", comment: "Accessibility hint for create account button")))
    }
  }

  var privacyNote: some View {
    Text(NSLocalizedString("welcome.privacyNote", value: "An active RefWatch account is required on iPhone. Your Apple Watch can still log matches offline and will sync once you sign in here.", comment: "Footer note explaining onboarding requirements"))
      .font(theme.typography.caption)
      .foregroundStyle(colors.privacyNoteText)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .frame(maxWidth: 360)
      .accessibilityHint(Text(NSLocalizedString("welcome.privacyNote.hint", value: "Explains why signing in is required on iPhone", comment: "Accessibility hint for the welcome privacy note")))
  }

  var cardHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 480 : 420
  }
}

private extension Collection {
  subscript(safe index: Index) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

#if DEBUG
#Preview {
  WelcomeView()
    .environmentObject(AuthenticationCoordinator(authController: SupabaseAuthController(
      clientProvider: SupabaseClientProvider.shared
    )))
    .theme(DefaultTheme())
}
#endif
