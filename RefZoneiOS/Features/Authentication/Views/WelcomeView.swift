//
//  WelcomeView.swift
//  RefZoneiOS
//
//  Introduces the app during the onboarding/authentication flow.
//

import RefWatchCore
import SwiftUI

/// A focused welcome screen that explains the benefits of signing in and
/// communicates that an account is required to use RefZone on iPhone.
struct WelcomeView: View {
    @EnvironmentObject private var coordinator: AuthenticationCoordinator
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.colors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    header
                    featureList
                    primaryActions
                    privacyNote
                }
                .padding(.horizontal, 32)
                .padding(.top, 80)
                .padding(.bottom, 48)
            }
        }
    }
}

private extension WelcomeView {
    var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .foregroundStyle(theme.colors.accentSecondary)
                .accessibilityHidden(true)

            Text("Welcome to RefZone")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Sign in to sync across devices, unlock match insights, and keep your officiating sharp.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Secure Supabase backups for match history", systemImage: "lock.shield")
            Label("Personalized trends and officiating insights", systemImage: "chart.line.uptrend.xyaxis")
            Label("Sync with your Apple Watch and teammates", systemImage: "applewatch")
        }
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    var primaryActions: some View {
        VStack(spacing: 16) {
            Button {
                coordinator.showSignIn()
            } label: {
                Text("Sign In")
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
        }
    }

    var privacyNote: some View {
        Text("An active RefZone account is required on iPhone. Your Apple Watch can still log matches offline and will sync once you sign in here.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
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
