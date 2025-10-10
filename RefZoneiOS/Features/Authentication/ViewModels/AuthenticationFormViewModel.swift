//
//  AuthenticationFormViewModel.swift
//  RefZoneiOS
//
//  Shared view model powering both sign-in and sign-up email forms.
//

import Combine
import Foundation
internal import os

/// Drives the email/password and third-party authentication buttons for dedicated auth views.
///
/// The view model wraps ``SupabaseAuthController`` so SwiftUI forms can present loading states,
/// error messaging, and trigger the correct Supabase operation for the configured mode.
///
/// ## Topics
/// ### Managing Form State
/// - ``email``
/// - ``password``
/// - ``isPerformingAction``
/// - ``alertMessage``
///
/// ### Performing Actions
/// - ``performPrimaryAction()``
/// - ``signInWithApple()``
/// - ``signInWithGoogle()``
@MainActor
final class AuthenticationFormViewModel: ObservableObject {
    /// Distinguishes between sign-in and sign-up flows.
    enum Mode {
        case signIn
        case signUp

        /// Title for the primary action button.
        var primaryButtonTitle: String {
            switch self {
            case .signIn: "Sign In"
            case .signUp: "Create Account"
            }
        }

        /// Supporting copy for the form's subheadline.
        var footnote: String {
            switch self {
            case .signIn:
                return "Keep your match history in sync, backed up, and ready with personalized insights."
            case .signUp:
                return "Create your RefZone account to sync matches securely across your devices."
            }
        }
    }

    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isPerformingAction: Bool = false
    @Published var alertMessage: String?

    let mode: Mode
    private let auth: SupabaseAuthController
    private var cancellables = Set<AnyCancellable>()

    init(mode: Mode, auth: SupabaseAuthController) {
        self.mode = mode
        self.auth = auth

        auth.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self else { return }
                self.alertMessage = error?.errorDescription
            }
            .store(in: &cancellables)
    }

    /// Runs the primary submit action for the current mode.
    /// - Returns: `true` when the Supabase operation completes successfully.
    @discardableResult
    func performPrimaryAction() async -> Bool {
        switch mode {
        case .signIn:
            return await signIn()
        case .signUp:
            return await signUp()
        }
    }

    /// Triggers Sign in with Apple.
    @discardableResult
    func signInWithApple() async -> Bool {
        await runAuthTask {
            try await auth.signInWithApple()
        }
    }

    /// Triggers Sign in with Google.
    @discardableResult
    func signInWithGoogle() async -> Bool {
        await runAuthTask {
            try await auth.signInWithGoogle()
        }
    }

    private func signIn() async -> Bool {
        await runAuthTask {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            try await auth.signIn(email: trimmed, password: password)
        }
    }

    private func signUp() async -> Bool {
        await runAuthTask {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            try await auth.signUp(email: trimmed, password: password)
        }
    }

    private func resetForm() {
        email = ""
        password = ""
    }

    private func runAuthTask(_ action: () async throws -> Void) async -> Bool {
        guard isPerformingAction == false else { return false }
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await action()
            resetForm()
            alertMessage = nil
            return true
        } catch {
            let mapped = SupabaseAuthError.map(error)
            AppLog.supabase.error("Auth flow failed: \(error.localizedDescription, privacy: .public)")
            alertMessage = mapped.errorDescription
            return false
        }
    }
}
