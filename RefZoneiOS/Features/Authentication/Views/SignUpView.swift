//
//  SignUpView.swift
//  RefZoneiOS
//
//  Dedicated account creation experience for the iOS app.
//

import RefWatchCore
import SwiftUI
import UIKit

/// Streamlined sign-up flow that mirrors the design system and highlights what users
/// gain by creating a RefZone account backed by Supabase auth.
struct SignUpView: View {
    @EnvironmentObject private var coordinator: AuthenticationCoordinator
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: AuthenticationFormViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(authController: SupabaseAuthController) {
        _viewModel = StateObject(wrappedValue: AuthenticationFormViewModel(mode: .signUp, auth: authController))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    form
                    federatedSection
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .scrollIndicators(.hidden)
            .background(colors.background.ignoresSafeArea())
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
        .tint(colors.accent)
    }
}

private extension SignUpView {
    var colors: AuthenticationScreenColors {
        AuthenticationScreenColors(theme: theme, colorScheme: colorScheme)
    }

    var header: some View {
        VStack(spacing: 12) {
            Text("Create your RefZone account")
                .font(.title2.bold())
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: 340, alignment: .leading)

            Text(viewModel.mode.footnote)
                .font(.subheadline)
                .foregroundStyle(colors.secondaryText)
                .frame(maxWidth: 340, alignment: .leading)
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
                .foregroundStyle(colors.primaryText)
                .authenticationInputField(colors: colors, isFocused: focusedField == .email)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submitPrimaryAction)
                .foregroundStyle(colors.primaryText)
                .authenticationInputField(colors: colors, isFocused: focusedField == .password)

            Text("At least 6 characters")
                .font(.footnote)
                .foregroundStyle(colors.subduedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: submitPrimaryAction) {
                if viewModel.isPerformingAction {
                    ProgressView()
                        .tint(colors.primaryActionForeground)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.mode.primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(AuthenticationPrimaryButtonStyle(colors: colors))
            .disabled(viewModel.isPerformingAction || viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.password.count < 6)
        }
        .accessibilityElement(children: .contain)
        .frame(maxWidth: 480)
    }

    var federatedSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1)
                    .frame(height: 1)
                    .foregroundStyle(colors.separator)

                Text("Or continue with")
                    .font(.footnote.weight(.semibold))
                    // .textCase(.uppercase)
                    .foregroundStyle(colors.secondaryText)

                RoundedRectangle(cornerRadius: 1)
                    .frame(height: 1)
                    .foregroundStyle(colors.separator)
            }

            Button(action: signInWithApple) {
                Label("Continue with Apple", systemImage: "applelogo")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(AuthenticationProviderButtonStyle(provider: .apple, colors: colors))
            .disabled(viewModel.isPerformingAction)

            Button(action: signInWithGoogle) {
                Label {
                    Text("Continue with Google")
                        .font(.body.weight(.semibold))
                } icon: {
                    Image(googleLogoAssetName)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(AuthenticationProviderButtonStyle(provider: .google, colors: colors))
            .disabled(viewModel.isPerformingAction)
        }
    }

    var footer: some View {
        VStack(spacing: 12) {
            Text("Creating an account keeps your match data backed up across RefZone. You can manage or delete it anytime from Settings.")
                .font(.footnote)
                .foregroundStyle(colors.subduedText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Already have an account? Sign in") {
                coordinator.showSignIn()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(colors.accent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { coordinator.dismiss() }
        }
    }

    var googleLogoAssetName: String {
        colorScheme == .dark ? "google-logo-dark-round" : "google-logo-neutral-round"
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
