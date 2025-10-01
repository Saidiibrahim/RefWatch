//
//  SignUpView.swift
//  RefZoneiOS
//
//  Dedicated account creation experience for the iOS app.
//

import RefWatchCore
import SwiftUI

/// Streamlined sign-up flow that mirrors the design system and highlights what users
/// gain by creating a RefZone account backed by Supabase auth.
struct SignUpView: View {
    @EnvironmentObject private var coordinator: AuthenticationCoordinator
    @Environment(\.theme) private var theme
    @StateObject private var viewModel: AuthenticationFormViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(authController: SupabaseAuthController) {
        _viewModel = StateObject(wrappedValue: AuthenticationFormViewModel(mode: .signUp, auth: authController))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    form
                    federatedSection
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(theme.colors.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Create Account")
            .toolbar { toolbar }
            .alert("Account", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { newValue in if !newValue { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }
}

private extension SignUpView {
    var header: some View {
        VStack(spacing: 12) {
            Text("Create your RefZone account")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.mode.footnote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var form: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            SecureField("Password", text: $viewModel.password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submitPrimaryAction)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button(action: submitPrimaryAction) {
                if viewModel.isPerformingAction {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.mode.primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isPerformingAction || viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.password.count < 6)
        }
        .accessibilityElement(children: .contain)
    }

    var federatedSection: some View {
        VStack(spacing: 12) {
            HStack {
                Rectangle().frame(height: 1).opacity(0.15)
                Text("Or use a quick login")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).opacity(0.15)
            }

            Button(action: signInWithApple) {
                Label("Continue with Apple", systemImage: "applelogo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(viewModel.isPerformingAction)

            Button(action: signInWithGoogle) {
                Label("Continue with Google", systemImage: "globe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isPerformingAction)
        }
    }

    var footer: some View {
        VStack(spacing: 12) {
            Text("By creating an account you agree to sync match data with Supabase. You can delete your account at any time from Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Already have an account? Sign in") {
                coordinator.showSignIn()
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
    }

    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { coordinator.dismiss() }
        }
    }

    func submitPrimaryAction() {
        guard viewModel.isPerformingAction == false else { return }
        Task {
            let succeeded = await viewModel.performPrimaryAction()
            if succeeded {
                coordinator.handleAuthenticationSuccess()
            }
        }
    }

    func signInWithApple() {
        guard viewModel.isPerformingAction == false else { return }
        Task {
            let succeeded = await viewModel.signInWithApple()
            if succeeded {
                coordinator.handleAuthenticationSuccess()
            }
        }
    }

    func signInWithGoogle() {
        guard viewModel.isPerformingAction == false else { return }
        Task {
            let succeeded = await viewModel.signInWithGoogle()
            if succeeded {
                coordinator.handleAuthenticationSuccess()
            }
        }
    }
}

#if DEBUG
#Preview {
    SignUpView(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
        .environmentObject(AuthenticationCoordinator(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)))
        .theme(DefaultTheme())
}
#endif
