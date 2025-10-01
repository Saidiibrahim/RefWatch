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
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    }
}

private extension SignedOutGateView {
    var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(theme.colors.accentSecondary)
                .accessibilityHidden(true)

            Text("Sign in to continue")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("RefZone on iPhone now requires a Supabase account. Sign in to access match tools, schedules, trends, and team management.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    var benefitList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Secure Supabase backups for match history", systemImage: "lock.shield")
            Label("Insights and trends across every match", systemImage: "chart.line.uptrend.xyaxis")
            Label("Manage teams and schedules in one place", systemImage: "calendar.badge.clock")
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    var actionStack: some View {
        VStack(spacing: 16) {
            Button {
                coordinator.showSignIn()
            } label: {
                Text(emailHint.map { "Sign back in as \($0)" } ?? "Sign In")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Opens the sign-in form")

            Button {
                coordinator.showSignUp()
            } label: {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Opens the account creation form")

            Button("Learn more about RefZone") {
                coordinator.showWelcome()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    var watchNote: some View {
        Text("Your Apple Watch can still run matches offline. As soon as you sign in here, we'll sync everything you've recorded.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
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
