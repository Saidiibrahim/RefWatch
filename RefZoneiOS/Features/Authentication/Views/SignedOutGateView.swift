//
//  SignedOutGateView.swift
//  RefZoneiOS
//
//  Blocking surface shown while the user is signed out on iPhone.
//

import SwiftUI
import RefWatchCore

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

private extension SignedOutGateView {
    var primaryTextColor: Color {
        colorScheme == .dark ? theme.colors.textPrimary : theme.colors.textInverted
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? theme.colors.textSecondary : theme.colors.textInverted
    }

    var backgroundView: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(colors: [theme.colors.backgroundPrimary, theme.colors.backgroundPrimary.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            } else {
                Color(uiColor: .systemBackground)
            }
        }
    }

    var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.colors.accentSecondary.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    .frame(width: 104, height: 104)

                Image(systemName: "lock.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundStyle(theme.colors.accentSecondary)
            }
            .accessibilityHidden(true)

            Text("Sign in to continue")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(primaryTextColor)

            Text("Sign in to keep your matches, timers, and teams in sync across your devices.")
                .font(.title3)
                .foregroundStyle(secondaryTextColor.opacity(colorScheme == .dark ? 0.86 : 0.75))
                .multilineTextAlignment(.center)
        }
    }

    var benefitList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Automatic cloud backup for match history", systemImage: "lock.shield")
            Label("Instant stats and trends after every match", systemImage: "chart.line.uptrend.xyaxis")
            Label("One place for teams, rosters, and schedules", systemImage: "calendar.badge.clock")
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.18), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }

    var actionStack: some View {
        VStack(spacing: 10) {
            Button {
                coordinator.showSignIn()
            } label: {
                Text(emailHint.map { "Sign back in as \($0)" } ?? "Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.accentSecondary)
            .accessibilityHint("Opens the sign-in form")

            Button {
                coordinator.showSignUp()
            } label: {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(secondaryTextColor.opacity(colorScheme == .dark ? 0.9 : 0.78))
            .accessibilityHint("Opens the account creation form")

            Button("See how RefZone works") {
                coordinator.showWelcome()
            }
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(secondaryTextColor)
            .padding(.top, 12)

            Text("Sign-in takes under 30 seconds.")
                .font(.footnote)
                .foregroundStyle(secondaryTextColor.opacity(colorScheme == .dark ? 0.75 : 0.62))
        }
    }
    var watchNote: some View {
        Text("Your Apple Watch still records matches offline. Sign in here to sync everything you've captured.")
            .font(.footnote)
            .foregroundStyle(secondaryTextColor.opacity(colorScheme == .dark ? 0.78 : 0.65))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom, 80)
            .frame(maxWidth: 320)
    }
}

#if DEBUG
#Preview {
    SignedOutGateView()
        .environmentObject(AuthenticationCoordinator(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)))
        .environmentObject(SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
        .theme(DefaultTheme())
}
#endif
