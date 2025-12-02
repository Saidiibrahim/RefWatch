//
//  SupabaseAuthController.swift
//  RefZoneiOS
//
//  Provides a supabase-native authentication flow, exposing the
//  AuthenticationProviding seam consumed throughout the app.
//

import Combine
import Foundation
import RefWatchCore
import Supabase
internal import os

/// A DocC-friendly authentication controller that wraps the Supabase Swift SDK and
/// exposes the app's vendor-agnostic `AuthenticationProviding` seam.
///
/// The controller centralizes:
/// - Credential validation before hitting the network.
/// - Interaction with Supabase native auth APIs (email/password and ID-token flows).
/// - Publishing session changes through an `@Published` `AuthState` so SwiftUI can react.
/// - Automatic user-profile synchronization so downstream stores always have an owning user row.
///
/// ## Topics
///
/// ### Getting Started
/// - ``SupabaseAuthController/init(clientProvider:profileSynchronizer:)``
/// - ``SupabaseAuthController/state``
///
/// ### Email and Password
/// - ``SupabaseAuthController/signIn(email:password:)``
/// - ``SupabaseAuthController/signUp(email:password:)``
///
/// ### Third-Party Identity Providers
/// - ``SupabaseAuthController/signInWithApple(coordinator:)``
/// - ``SupabaseAuthController/signInWithGoogle(coordinator:)``
///
/// ### Session Lifecycle
/// - ``SupabaseAuthController/signOut()``
/// - ``SupabaseAuthController/restoreSessionIfAvailable()``
///
/// ### Diagnostics
/// - ``SupabaseAuthController/lastError``
/// - ``SupabaseAuthController/clearLastError()``
///
/// ### Supporting Types
/// - ``SupabaseAuthStateProviding``
/// - ``SupabaseAuthError``
///
/// Use ``SupabaseAuthController`` as a shared `@StateObject` so the app has a single source
/// of truth for authentication.

/// An extension of ``AuthenticationProviding`` that surfaces a Combine publisher for doc-friendly composition.
@MainActor
protocol SupabaseAuthStateProviding: AuthenticationProviding {
    /// A publisher that emits whenever ``SupabaseAuthController/state`` changes.
    var statePublisher: AnyPublisher<AuthState, Never> { get }
}

@MainActor
final class SupabaseAuthController: ObservableObject {
    /// The authoritative authentication state consumed by SwiftUI views and stores.
    @Published private(set) var state: AuthState = .signedOut
    /// The most recent user-presentable error emitted by a Supabase auth flow.
    @Published private(set) var lastError: SupabaseAuthError?

    private enum ControllerError: Swift.Error {
        case supabaseClientUnavailable
    }

    private let clientProvider: SupabaseClientProviding
    private let profileSynchronizer: SupabaseUserProfileSynchronizing
    private let credentialValidator = SupabaseCredentialValidator()
    private var authStateSubscription: Task<Void, Never>?
    private var profileSyncTask: Task<Void, Never>?

    /// Creates a Supabase-auth backed controller.
    ///
    /// - Parameters:
    ///   - clientProvider: A shared client provider that resolves the configured Supabase project.
    ///   - profileSynchronizer: Optional synchronizer used to upsert `public.users` rows.
    init(
        clientProvider: SupabaseClientProviding,
        profileSynchronizer: SupabaseUserProfileSynchronizing? = nil
    ) {
        self.clientProvider = clientProvider
        self.profileSynchronizer = profileSynchronizer ?? SupabaseUserProfileSynchronizer(clientProvider: clientProvider)
        Task { await restoreSessionIfAvailable() }
        observeAuthChanges()
    }

    deinit {
        authStateSubscription?.cancel()
        authStateSubscription = nil
        profileSyncTask?.cancel()
        profileSyncTask = nil
    }

    // MARK: - AuthenticationProviding

    /// Convenience accessor for the signed-in user's UUID string.
    var currentUserId: String? {
        if case let .signedIn(userId, _, _) = state { return userId }
        return nil
    }

    /// Indicates whether the user currently has an authenticated Supabase session.
    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// Reads the user's email from the latest session snapshot.
    var currentEmail: String? {
        if case let .signedIn(_, email, _) = state { return email }
        return nil
    }

    /// The rich display name resolved from metadata, falling back to the email address.
    var currentDisplayName: String? {
        if case let .signedIn(_, _, name) = state { return name }
        return nil
    }

    var statePublisher: AnyPublisher<AuthState, Never> {
        $state.removeDuplicates().eraseToAnyPublisher()
    }

    // MARK: - Public API

    /// Signs the user in using email/password credentials and publishes the resulting session.
    ///
    /// - Parameters:
    ///   - email: The email address to authenticate with.
    ///   - password: The user's password.
    /// - Throws: ``SupabaseAuthError`` when validation or network operations fail.
    func signIn(email: String, password: String) async throws {
        do {
            try credentialValidator.validate(email: email, password: password)
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }

        let client = try resolveClient()

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            refreshState(using: session)
            clearLastError()
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }
    }

    /// Creates a new Supabase user and publishes the resulting session (if immediate).
    ///
    /// - Note: Supabase may require email confirmation. When no session is returned the controller surfaces ``SupabaseAuthError/emailConfirmationRequired(email:)``.
    /// - Parameters:
    ///   - email: The desired account email.
    ///   - password: The desired password.
    /// - Throws: ``SupabaseAuthError`` when validation fails or Supabase returns an error.
    func signUp(email: String, password: String) async throws {
        do {
            try credentialValidator.validate(email: email, password: password)
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }

        let client = try resolveClient()
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if let session = response.session {
                refreshState(using: session)
                clearLastError()
            } else {
                refreshState(using: nil)
                let confirmationError = SupabaseAuthError.emailConfirmationRequired(email: email)
                lastError = confirmationError
                throw confirmationError
            }
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }
    }

    /// Performs Sign in With Apple, handing the ID token to Supabase auth.
    ///
    /// - Parameter coordinator: Optionally supply a test double for driving Apple auth.
    /// - Throws: ``SupabaseAuthError`` when presentation fails, the user cancels, or Supabase rejects the token.
    func signInWithApple(
        coordinator: SupabaseAppleSignInCoordinating? = nil
    ) async throws {
        let client = try resolveClient()
        do {
            let actualCoordinator = coordinator ?? SupabaseAppleSignInCoordinator()
            let credentials = try await actualCoordinator.signIn()
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: credentials.idToken,
                    nonce: credentials.nonce
                )
            )
            refreshState(using: session)
            clearLastError()
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }
    }

    /// Signs the user in with Google Identity Services, exchanging the ID token with Supabase.
    ///
    /// - Parameter coordinator: Optionally inject a mock for unit testing.
    /// - Throws: ``SupabaseAuthError`` when the Google SDK or Supabase fails.
    func signInWithGoogle(
        coordinator: SupabaseGoogleSignInCoordinating? = nil
    ) async throws {
        let client = try resolveClient()
        do {
            let actualCoordinator = coordinator ?? SupabaseGoogleSignInCoordinator()
            let credentials = try await actualCoordinator.signIn()
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: credentials.idToken,
                    nonce: credentials.nonce
                )
            )
            refreshState(using: session)
            clearLastError()
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }
    }

    /// Signs the current user out of Supabase and resets the published state.
    ///
    /// - Throws: ``SupabaseAuthError`` if Supabase rejects the request.
    func signOut() async throws {
        let client = try resolveClient()
        do {
            try await client.auth.signOut()
            refreshState(using: nil)
            clearLastError()
        } catch {
            let mapped = SupabaseAuthError.map(error)
            lastError = mapped
            throw mapped
        }
    }

    /// Attempts to load an existing Supabase session without prompting the user.
    ///
    /// Call this when the app becomes active or launches cold to resume auth-linked features.
    func restoreSessionIfAvailable() async {
        guard let client = try? resolveClient() else {
            refreshState(using: nil)
            return
        }
        do {
            let session = try await client.auth.session
            refreshState(using: session)
        } catch {
            refreshState(using: nil)
        }
        clearLastError()
    }

    /// Clears ``SupabaseAuthController/lastError`` to dismiss user-facing alerts.
    func clearLastError() {
        lastError = nil
    }

    // MARK: - Helpers

    private func resolveClient() throws -> SupabaseClient {
        let client = try clientProvider.client()
        guard let supabaseClient = client as? SupabaseClient else {
            throw ControllerError.supabaseClientUnavailable
        }
        return supabaseClient
    }

    private func observeAuthChanges() {
        guard let client = try? resolveClient() else { return }
        authStateSubscription = Task {
            for await (_, session) in client.auth.authStateChanges {
                Task { @MainActor in
                    self.refreshState(using: session)
                }
            }
        }
    }

    private func refreshState(using session: Session?) {
        if let session {
            let userId = session.user.id.uuidString
            let email = session.user.email
            let displayName = SupabaseAuthController.bestDisplayName(from: session.user)
            state = .signedIn(userId: userId, email: email, displayName: displayName)

            profileSyncTask?.cancel()
            profileSyncTask = Task {
                do {
                    try await profileSynchronizer.syncIfNeeded(session: session)
                } catch {
                    AppLog.supabase.error("User profile sync failed: \(error.localizedDescription, privacy: .public)")
                }
                await clientProvider.refreshFunctionAuth()
            }
        } else {
            state = .signedOut
            profileSyncTask?.cancel()
            profileSyncTask = nil
            Task {
                await clientProvider.refreshFunctionAuth()
            }
        }
    }

    private static func bestDisplayName(from user: User) -> String? {
        let metadata = user.userMetadata
        if let name = string(for: "full_name", in: metadata) { return name }
        if let display = string(for: "display_name", in: metadata) { return display }
        if let username = string(for: "username", in: metadata) { return username }
        if let email = user.email, email.isEmpty == false { return email }
        return nil
    }

    private static func string(for key: String, in metadata: [String: Any]?) -> String? {
        guard let value = metadata?[key] else { return nil }
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}

@MainActor
extension SupabaseAuthController: SupabaseAuthStateProviding {}
