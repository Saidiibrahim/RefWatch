//
//  SignedOutGateView.swift
//  RefWatchiOS
//
//  Blocking surface shown while the user is signed out on iPhone.
//

import RefWatchCore
import SwiftUI

/// Centralized color helper for SignedOutGateView that adapts to light/dark mode
struct SignedOutGateColors {
  let background: Color
  let primaryText: Color
  let secondaryText: Color
  let tertiaryText: Color
  let quaternaryText: Color
  let heroIconBackground: Color
  let heroIcon: Color
  let cardShadow: Color
  let primaryButtonTint: Color
  let secondaryButtonTint: Color

  init(theme: AnyTheme, colorScheme: ColorScheme) {
    let accentSecondary = theme.colors.accentSecondary
    let accentPrimary = theme.colors.accentPrimary

    switch colorScheme {
    case .dark:
      // Preserve existing dark mode behavior
      self.background = theme.colors.backgroundPrimary
      self.primaryText = theme.colors.textPrimary
      self.secondaryText = theme.colors.textSecondary
      self.tertiaryText = theme.colors.textSecondary.opacity(0.86)
      self.quaternaryText = theme.colors.textSecondary.opacity(0.72)
      self.heroIconBackground = accentSecondary.opacity(0.18)
      self.heroIcon = accentSecondary
      self.cardShadow = Color.black.opacity(0.26)
      self.primaryButtonTint = accentSecondary
      self.secondaryButtonTint = theme.colors.textSecondary.opacity(0.9)

    default: // .light
      // New minimal, clean light mode
      self.background = Color(uiColor: .systemBackground)
      self.primaryText = Color(uiColor: .label)
      self.secondaryText = Color(uiColor: .secondaryLabel)
      self.tertiaryText = Color(uiColor: .secondaryLabel).opacity(0.75)
      self.quaternaryText = Color(uiColor: .tertiaryLabel)
      self.heroIconBackground = accentSecondary.opacity(0.08)
      self.heroIcon = accentSecondary
      self.cardShadow = Color.black.opacity(0.08)
      self.primaryButtonTint = accentSecondary
      self.secondaryButtonTint = accentPrimary
    }
  }
}

/// A blocking experience that clearly communicates the signed-in requirement on iPhone
/// while routing users into the authentication flow.
struct SignedOutGateView: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator
  @EnvironmentObject private var authController: SupabaseAuthController
  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  private var emailHint: String? {
    if case let .signedIn(_, email, _) = authController.state {
      return email
    }
    return nil
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        hero
        benefitList
        actionStack
        watchNote
      }
      .padding(.horizontal, 32)
      .padding(.top, 96)
      .padding(.bottom, 48)
    }
    .background(backgroundView.ignoresSafeArea())
  }
}

extension SignedOutGateView {
  fileprivate var colors: SignedOutGateColors {
    SignedOutGateColors(theme: self.theme, colorScheme: self.colorScheme)
  }

  private var backgroundView: some View {
    Group {
      if self.colorScheme == .dark {
        LinearGradient(
          colors: [self.theme.colors.backgroundPrimary, self.theme.colors.backgroundPrimary.opacity(0.9)],
          startPoint: .top,
          endPoint: .bottom)
      } else {
        self.colors.background
      }
    }
  }

  private var hero: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(self.colors.heroIconBackground)
          .frame(width: 104, height: 104)

        Image(systemName: "lock.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 64, height: 64)
          .foregroundStyle(self.colors.heroIcon)
      }
      .accessibilityHidden(true)

      Text("Sign in to continue")
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
        .foregroundStyle(self.colors.primaryText)

      Text("Sign in to keep your matches, timers, and teams in sync across your devices.")
        .font(.title3)
        .foregroundStyle(self.colors.secondaryText)
        .multilineTextAlignment(.center)
    }
  }

  private var benefitList: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Automatic cloud backup for match history", systemImage: "lock.shield")
      Label("Instant stats and trends after every match", systemImage: "chart.line.uptrend.xyaxis")
      Label("One place for teams, rosters, and schedules", systemImage: "calendar.badge.clock")
    }
    .font(.headline)
    .foregroundStyle(self.colors.primaryText)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .shadow(color: self.colors.cardShadow, radius: 14, y: 6)
    .accessibilityElement(children: .contain)
  }

  private var actionStack: some View {
    VStack(spacing: 10) {
      Button {
        self.coordinator.showSignIn()
      } label: {
        Text(self.emailHint.map { "Sign back in as \($0)" } ?? "Sign In")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .tint(self.colors.primaryButtonTint)
      .accessibilityHint("Opens the sign-in form")

      Button {
        self.coordinator.showSignUp()
      } label: {
        Text("Create Account")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(self.colors.secondaryButtonTint)
      .accessibilityHint("Opens the account creation form")

      Button("See how RefWatch works") {
        self.coordinator.showWelcome()
      }
      .buttonStyle(.plain)
      .font(.system(size: 15, weight: .medium))
      .foregroundStyle(self.colors.secondaryText)
      .padding(.top, 12)

      Text("Sign-in takes under 30 seconds.")
        .font(.footnote)
        .foregroundStyle(self.colors.tertiaryText)
    }
  }

  private var watchNote: some View {
    Text("Your Apple Watch still records matches offline. Sign in here to sync everything you've captured.")
      .font(.footnote)
      .foregroundStyle(self.colors.quaternaryText)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      .padding(.bottom, 80)
      .frame(maxWidth: 320)
  }
}

#if DEBUG
#Preview {
  SignedOutGateView()
    .environmentObject(
      AuthenticationCoordinator(
        authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)))
    .environmentObject(SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
    .theme(DefaultTheme())
}
#endif
