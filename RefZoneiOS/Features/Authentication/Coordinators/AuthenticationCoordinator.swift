//
//  AuthenticationCoordinator.swift
//  RefZoneiOS
//
//  Created to orchestrate the dedicated onboarding and authentication flow.
//

import Combine
import RefWatchCore
import SwiftUI

/// Coordinates presentation of the onboarding and authentication flow for the iOS app.
///
/// The coordinator owns lightweight navigation state so top-level views can trigger the
/// appropriate full-screen experience without embedding authentication forms themselves.
/// It also persists the user's onboarding completion flag so the welcome screen is only
/// surfaced when it delivers value.
///
/// ## Topics
/// ### Presenting the Flow
/// - ``presentWelcomeIfNeeded()``
/// - ``showWelcome()``
/// - ``showSignIn()``
/// - ``showSignUp()``
/// - ``dismiss()``
///
/// ### Responding to Auth State
/// - ``handleAuthenticationSuccess()``
@MainActor
final class AuthenticationCoordinator: ObservableObject {
    /// Logical screens that can be rendered by the authentication flow.
    enum Screen: Identifiable, Equatable {
        case welcome
        case signIn
        case signUp

        var id: String {
            switch self {
            case .welcome: "welcome"
            case .signIn: "signIn"
            case .signUp: "signUp"
            }
        }
    }

    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @Published var activeScreen: Screen?

    private let authController: SupabaseAuthController
    private var stateCancellable: AnyCancellable?

    init(authController: SupabaseAuthController) {
        self.authController = authController
        stateCancellable = authController.$state
            .removeDuplicates()
            .sink { [weak self] state in
                self?.evaluatePresentation(for: state)
            }

        evaluatePresentation(for: authController.state)
    }

    // MARK: - Screen Routing

    /// Presents the onboarding experience the first time the user launches while signed out.
    func presentWelcomeIfNeeded() {
        guard hasCompletedOnboarding == false else { return }
        showWelcome()
    }

    /// Presents the welcome view regardless of onboarding status.
    func showWelcome() {
        withAnimation { activeScreen = .welcome }
    }

    /// Presents the sign-in form.
    func showSignIn() {
        hasCompletedOnboarding = true
        withAnimation { activeScreen = .signIn }
    }

    /// Presents the sign-up form.
    func showSignUp() {
        hasCompletedOnboarding = true
        withAnimation { activeScreen = .signUp }
    }

    /// Dismisses the flow entirely.
    func dismiss() {
        withAnimation { activeScreen = nil }
    }

    /// Handles successful authentication and dismisses the flow.
    func handleAuthenticationSuccess() {
        hasCompletedOnboarding = true
        dismiss()
    }

    /// Ensures the welcome view is presented when the user has not completed onboarding.
    private func evaluatePresentation(for state: AuthState) {
        switch state {
        case .signedOut:
            if hasCompletedOnboarding == false {
                withAnimation { activeScreen = .welcome }
            } else if activeScreen != .signIn {
                withAnimation { activeScreen = .signIn }
            }
        case .signedIn:
            handleAuthenticationSuccess()
        }
    }
}
