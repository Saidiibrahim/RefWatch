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

protocol SupabaseAuthStateProviding: AuthenticationProviding {
    var statePublisher: AnyPublisher<AuthState, Never> { get }
}

@MainActor
final class SupabaseAuthController: ObservableObject, SupabaseAuthStateProviding {
    @Published private(set) var state: AuthState = .signedOut
    @Published private(set) var lastError: SupabaseAuthError?

    private enum ControllerError: Swift.Error {
        case supabaseClientUnavailable
    }

    private let clientProvider: SupabaseClientProviding
    private let credentialValidator = SupabaseCredentialValidator()
    private var authStateSubscription: Task<Void, Never>?

    init(clientProvider: SupabaseClientProviding) {
        self.clientProvider = clientProvider
        Task { await restoreSessionIfAvailable() }
        observeAuthChanges()
    }

    deinit {
        authStateSubscription?.cancel()
        authStateSubscription = nil
    }

    // MARK: - AuthenticationProviding

    var currentUserId: String? {
        if case let .signedIn(userId, _, _) = state { return userId }
        return nil
    }

    var currentEmail: String? {
        if case let .signedIn(_, email, _) = state { return email }
        return nil
    }

    var currentDisplayName: String? {
        if case let .signedIn(_, _, name) = state { return name }
        return nil
    }

    var statePublisher: AnyPublisher<AuthState, Never> {
        $state.removeDuplicates().eraseToAnyPublisher()
    }

    // MARK: - Public API

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
        } else {
            state = .signedOut
        }

        clientProvider.refreshFunctionAuth()
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
