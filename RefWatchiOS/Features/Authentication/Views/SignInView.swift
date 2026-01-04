//
//  SignInView.swift
//  RefWatchiOS
//
//  Dedicated email and federated sign-in experience for iOS.
//

import RefWatchCore
import SwiftUI
import UIKit

/// A focused sign-in experience that mirrors iOS design conventions, highlighting
/// that an active Supabase session is required on iPhone.
struct SignInView: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator
  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel: AuthenticationFormViewModel
  @FocusState private var focusedField: Field?

  private enum Field { case email, password }

  init(authController: SupabaseAuthController) {
    _viewModel = StateObject(wrappedValue: AuthenticationFormViewModel(mode: .signIn, auth: authController))
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
      .navigationTitle("Sign In")
      .toolbar { toolbar }
      .alert("Authentication", isPresented: Binding(
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

extension SignInView {
  fileprivate var colors: AuthenticationScreenColors {
    AuthenticationScreenColors(theme: self.theme, colorScheme: self.colorScheme)
  }

  private var header: some View {
    VStack(spacing: 12) {
      Text("Sign in to use RefWatch on iPhone")
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
        .textContentType(.password)
        .focused(self.$focusedField, equals: .password)
        .submitLabel(.go)
        .onSubmit(self.submitPrimaryAction)
        .foregroundStyle(self.colors.primaryText)
        .authenticationInputField(colors: self.colors, isFocused: self.focusedField == .password)

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
          .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.viewModel.password.isEmpty)
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
        Label("Sign in with Apple", systemImage: "applelogo")
          .font(.body.weight(.semibold))
          .frame(maxWidth: .infinity, alignment: .center)
      }
      .buttonStyle(AuthenticationProviderButtonStyle(provider: .apple, colors: self.colors))
      .disabled(self.viewModel.isPerformingAction)

      Button(action: self.signInWithGoogle) {
        Label {
          Text("Sign in with Google")
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
    VStack(spacing: 8) {
      Button {
        self.coordinator.showSignUp()
      } label: {
        Text("Need an account? Create one")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(self.colors.accent)
      }
      .padding(.top, 8)

      Text(
        "Signing in keeps RefWatch on iPhone and Apple Watch in sync. " +
          "Your watch works offline and updates when you return here.")
        .font(.footnote)
        .foregroundStyle(self.colors.subduedText)
        .multilineTextAlignment(.center)
        .padding(.top, 4)
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

// MARK: - Styling Helpers

struct AuthenticationScreenColors {
  let background: Color
  let surface: Color
  let outline: Color
  let separator: Color
  let primaryText: Color
  let secondaryText: Color
  let accent: Color
  let primaryActionBackground: Color
  let primaryActionForeground: Color
  let buttonShadow: Color
  let subduedText: Color

  init(theme: AnyTheme, colorScheme: ColorScheme) {
    let accentBackground = theme.colors.accentSecondary
    switch colorScheme {
    case .dark:
      self.background = theme.colors.backgroundPrimary
      self.surface = theme.colors.backgroundSecondary
      self.outline = theme.colors.outlineMuted
      self.separator = theme.colors.outlineMuted.opacity(0.24)
      self.primaryText = theme.colors.textPrimary
      self.secondaryText = theme.colors.textSecondary
      self.accent = accentBackground
      self.buttonShadow = Color.black.opacity(0.45)
      self.subduedText = theme.colors.textSecondary.opacity(0.86)
    default:
      self.background = Color(uiColor: .systemBackground)
      self.surface = Color(uiColor: .secondarySystemBackground)
      self.outline = Color(uiColor: .separator).opacity(0.35)
      self.separator = Color(uiColor: .separator).opacity(0.6)
      self.primaryText = Color(uiColor: .label)
      self.secondaryText = Color(uiColor: .secondaryLabel)
      self.accent = accentBackground
      self.buttonShadow = Color.black.opacity(0.12)
      self.subduedText = Color(uiColor: .secondaryLabel).opacity(0.72)
    }

    self.primaryActionBackground = accentBackground
    self.primaryActionForeground = Color.white
  }
}

struct AuthenticationInputFieldModifier: ViewModifier {
  let colors: AuthenticationScreenColors
  let isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(self.colors.surface))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(self.isFocused ? self.colors.accent : self.colors.outline, lineWidth: 1))
      .shadow(color: self.colors.buttonShadow.opacity(self.colorScheme == .dark ? 0 : 0.06), radius: 10, y: 4)
  }
}

extension View {
  func authenticationInputField(colors: AuthenticationScreenColors, isFocused: Bool) -> some View {
    modifier(AuthenticationInputFieldModifier(colors: colors, isFocused: isFocused))
  }
}

struct AuthenticationPrimaryButtonStyle: ButtonStyle {
  let colors: AuthenticationScreenColors
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed && self.isEnabled
    let background = self.colors.accent
    let foreground = Color.white
    let border = self.colors.accent.opacity(self.isEnabled ? 0.4 : 0.15)
    let shadowOpacity = self.isEnabled ? (pressed ? 0.20 : 0.28) : 0

    return configuration.label
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(foreground)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 52)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(background))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(border, lineWidth: 1))
      .shadow(color: self.colors.buttonShadow.opacity(shadowOpacity), radius: pressed ? 3 : 6, y: pressed ? 2 : 6)
      .scaleEffect(pressed ? 0.98 : 1)
      .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

struct AuthenticationProviderButtonStyle: ButtonStyle {
  enum Provider {
    case apple
    case google
  }

  let provider: Provider
  let colors: AuthenticationScreenColors

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    let palette = palette(for: provider)
    let pressed = configuration.isPressed && self.isEnabled
    let opacity = self.isEnabled ? 1.0 : 0.65
    let shadowOpacity = pressed ? 0.18 : 0.24

    return configuration.label
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(palette.foreground.opacity(opacity))
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(palette.background.opacity(opacity)))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(palette.border.opacity(opacity), lineWidth: palette.borderWidth))
      .shadow(
        color: palette.shadow.opacity(self.isEnabled ? shadowOpacity : 0),
        radius: pressed ? 2 : 5,
        y: pressed ? 1 : 4)
      .scaleEffect(pressed ? 0.98 : 1)
      .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func palette(for provider: Provider) -> ProviderPalette {
    switch provider {
    case .apple:
      if self.colorScheme == .dark {
        return ProviderPalette(
          background: Color.white,
          foreground: Color.black,
          border: .clear,
          borderWidth: 0,
          shadow: Color.black)
      } else {
        return ProviderPalette(
          background: Color.black,
          foreground: Color.white,
          border: .clear,
          borderWidth: 0,
          shadow: Color.black.opacity(0.45))
      }
    case .google:
      let borderColor = self.colorScheme == .dark ? Color.white.opacity(0.25) : self.colors.separator
      let shadowColor = Color.black.opacity(self.colorScheme == .dark ? 0.35 : 0.14)
      return ProviderPalette(
        background: Color.white,
        foreground: Color.black.opacity(0.85),
        border: borderColor,
        borderWidth: 1,
        shadow: shadowColor)
    }
  }

  private struct ProviderPalette {
    let background: Color
    let foreground: Color
    let border: Color
    let borderWidth: CGFloat
    let shadow: Color
  }
}

#if DEBUG
#Preview {
  SignInView(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
    .environmentObject(
      AuthenticationCoordinator(authController: SupabaseAuthController(
        clientProvider: SupabaseClientProvider
          .shared)))
    .theme(DefaultTheme())
}
#endif
