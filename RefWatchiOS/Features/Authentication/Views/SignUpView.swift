//
//  SignUpView.swift
//  RefWatchiOS
//
//  Dedicated account creation experience for the iOS app.
//

import RefWatchCore
import SwiftUI
import UIKit

/// Streamlined sign-up flow that mirrors the design system and highlights what users
/// gain by creating a RefWatch account backed by Supabase auth.
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
        get: { self.viewModel.alertMessage != nil },
        set: { newValue in if !newValue { self.viewModel.alertMessage = nil } }
      )) {
        Button("OK", role: .cancel) { self.viewModel.alertMessage = nil }
      } message: {
        Text(self.viewModel.alertMessage ?? "")
      }
    }
    .tint(colors.accent)
  }
}

extension SignUpView {
  private var colors: AuthenticationScreenColors {
    AuthenticationScreenColors(theme: self.theme, colorScheme: self.colorScheme)
  }

  private var header: some View {
    VStack(spacing: 12) {
      Text("Create your RefWatch account")
        .font(.title2.bold())
        .foregroundStyle(self.colors.primaryText)
        .frame(maxWidth: 340, alignment: .leading)

      Text(self.viewModel.mode.footnote)
        .font(.subheadline)
        .foregroundStyle(self.colors.secondaryText)
        .frame(maxWidth: 340, alignment: .leading)
    }
  }

  private var form: some View {
    VStack(spacing: 16) {
      TextField("Email", text: self.$viewModel.email)
        .keyboardType(.emailAddress)
        .textContentType(.username)
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .focused(self.$focusedField, equals: .email)
        .submitLabel(.next)
        .onSubmit { self.focusedField = .password }
        .foregroundStyle(self.colors.primaryText)
        .authenticationInputField(colors: self.colors, isFocused: self.focusedField == .email)

      SecureField("Password", text: self.$viewModel.password)
        .textContentType(.newPassword)
        .focused(self.$focusedField, equals: .password)
        .submitLabel(.go)
        .onSubmit(self.submitPrimaryAction)
        .foregroundStyle(self.colors.primaryText)
        .authenticationInputField(colors: self.colors, isFocused: self.focusedField == .password)

      Text("At least 6 characters")
        .font(.footnote)
        .foregroundStyle(self.colors.subduedText)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: self.submitPrimaryAction) {
        if self.viewModel.isPerformingAction {
          ProgressView()
            .tint(self.colors.primaryActionForeground)
            .frame(maxWidth: .infinity)
        } else {
          Text(self.viewModel.mode.primaryButtonTitle)
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(AuthenticationPrimaryButtonStyle(colors: self.colors))
      .disabled(
        self.viewModel.isPerformingAction || self.viewModel.email
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.viewModel.password.count < 6)
    }
    .accessibilityElement(children: .contain)
    .frame(maxWidth: 480)
  }

  private var federatedSection: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 1)
          .frame(height: 1)
          .foregroundStyle(self.colors.separator)

        Text("Or continue with")
          .font(.footnote.weight(.semibold))
          // .textCase(.uppercase)
          .foregroundStyle(self.colors.secondaryText)

        RoundedRectangle(cornerRadius: 1)
          .frame(height: 1)
          .foregroundStyle(self.colors.separator)
      }

      Button(action: self.signInWithApple) {
        Label("Continue with Apple", systemImage: "applelogo")
          .font(.body.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .buttonStyle(AuthenticationProviderButtonStyle(provider: .apple, colors: self.colors))
      .disabled(self.viewModel.isPerformingAction)

      Button(action: self.signInWithGoogle) {
        Label {
          Text("Continue with Google")
            .font(.body.weight(.semibold))
        } icon: {
          Image(self.googleLogoAssetName)
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .center)
      }
      .buttonStyle(AuthenticationProviderButtonStyle(provider: .google, colors: self.colors))
      .disabled(self.viewModel.isPerformingAction)
    }
  }

  private var footer: some View {
    VStack(spacing: 12) {
      Text(
        "Creating an account keeps your match data backed up across RefWatch. " +
          "You can manage or delete it anytime from Settings.")
        .font(.footnote)
        .foregroundStyle(self.colors.subduedText)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button("Already have an account? Sign in") {
        self.coordinator.showSignIn()
      }
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(self.colors.accent)
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity)
  }

  private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button("Cancel") { self.coordinator.dismiss() }
    }
  }

  private var googleLogoAssetName: String {
    self.colorScheme == .dark ? "google-logo-dark-round" : "google-logo-neutral-round"
  }

  private func submitPrimaryAction() {
    guard self.viewModel.isPerformingAction == false else { return }
    Task {
      let succeeded = await viewModel.performPrimaryAction()
      if succeeded {
        self.coordinator.handleAuthenticationSuccess()
      }
    }
  }

  private func signInWithApple() {
    guard self.viewModel.isPerformingAction == false else { return }
    Task {
      let succeeded = await viewModel.signInWithApple()
      if succeeded {
        self.coordinator.handleAuthenticationSuccess()
      }
    }
  }

  private func signInWithGoogle() {
    guard self.viewModel.isPerformingAction == false else { return }
    Task {
      let succeeded = await viewModel.signInWithGoogle()
      if succeeded {
        self.coordinator.handleAuthenticationSuccess()
      }
    }
  }
}

#if DEBUG
#Preview {
  SignUpView(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
    .environmentObject(
      AuthenticationCoordinator(authController: SupabaseAuthController(
        clientProvider: SupabaseClientProvider
          .shared)))
    .theme(DefaultTheme())
}
#endif
