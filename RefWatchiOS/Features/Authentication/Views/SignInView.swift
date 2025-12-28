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

private extension SignInView {
    var colors: AuthenticationScreenColors {
        AuthenticationScreenColors(theme: theme, colorScheme: colorScheme)
    }

    var header: some View {
        VStack(spacing: 12) {
            Text("Sign in to use RefWatch on iPhone")
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
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submitPrimaryAction)
                .foregroundStyle(colors.primaryText)
                .authenticationInputField(colors: colors, isFocused: focusedField == .password)

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
            .disabled(viewModel.isPerformingAction || viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.password.isEmpty)
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
                Label("Sign in with Apple", systemImage: "applelogo")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(AuthenticationProviderButtonStyle(provider: .apple, colors: colors))
            .disabled(viewModel.isPerformingAction)

            Button(action: signInWithGoogle) {
                Label {
                    Text("Sign in with Google")
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
        VStack(spacing: 8) {
            Button {
                coordinator.showSignUp()
            } label: {
                Text("Need an account? Create one")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.accent)
            }
            .padding(.top, 8)

            Text("Signing in keeps RefWatch on iPhone and Apple Watch in sync. Your watch works offline and updates when you return here.")
                .font(.footnote)
                .foregroundStyle(colors.subduedText)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
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
            background = theme.colors.backgroundPrimary
            surface = theme.colors.backgroundSecondary
            outline = theme.colors.outlineMuted
            separator = theme.colors.outlineMuted.opacity(0.24)
            primaryText = theme.colors.textPrimary
            secondaryText = theme.colors.textSecondary
            accent = accentBackground
            buttonShadow = Color.black.opacity(0.45)
            subduedText = theme.colors.textSecondary.opacity(0.86)
        default:
            background = Color(uiColor: .systemBackground)
            surface = Color(uiColor: .secondarySystemBackground)
            outline = Color(uiColor: .separator).opacity(0.35)
            separator = Color(uiColor: .separator).opacity(0.6)
            primaryText = Color(uiColor: .label)
            secondaryText = Color(uiColor: .secondaryLabel)
            accent = accentBackground
            buttonShadow = Color.black.opacity(0.12)
            subduedText = Color(uiColor: .secondaryLabel).opacity(0.72)
        }

        primaryActionBackground = accentBackground
        primaryActionForeground = Color.white
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
                    .fill(colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? colors.accent : colors.outline, lineWidth: 1)
            )
            .shadow(color: colors.buttonShadow.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 4)
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
        let pressed = configuration.isPressed && isEnabled
        let background = colors.accent
        let foreground = Color.white
        let border = colors.accent.opacity(isEnabled ? 0.4 : 0.15)
        let shadowOpacity = isEnabled ? (pressed ? 0.20 : 0.28) : 0

        return configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: colors.buttonShadow.opacity(shadowOpacity), radius: pressed ? 3 : 6, y: pressed ? 2 : 6)
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
        let pressed = configuration.isPressed && isEnabled
        let opacity = isEnabled ? 1.0 : 0.65
        let shadowOpacity = pressed ? 0.18 : 0.24

        return configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(palette.foreground.opacity(opacity))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.background.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border.opacity(opacity), lineWidth: palette.borderWidth)
            )
            .shadow(color: palette.shadow.opacity(isEnabled ? shadowOpacity : 0), radius: pressed ? 2 : 5, y: pressed ? 1 : 4)
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func palette(for provider: Provider) -> (background: Color, foreground: Color, border: Color, borderWidth: CGFloat, shadow: Color) {
        switch provider {
        case .apple:
            if colorScheme == .dark {
                return (background: Color.white, foreground: Color.black, border: .clear, borderWidth: 0, shadow: Color.black)
            } else {
                return (background: Color.black, foreground: Color.white, border: .clear, borderWidth: 0, shadow: Color.black.opacity(0.45))
            }
        case .google:
            let borderColor = colorScheme == .dark ? Color.white.opacity(0.25) : colors.separator
            let shadowColor = Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14)
            return (background: Color.white, foreground: Color.black.opacity(0.85), border: borderColor, borderWidth: 1, shadow: shadowColor)
        }
    }
}

#if DEBUG
#Preview {
    SignInView(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared))
        .environmentObject(AuthenticationCoordinator(authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)))
        .theme(DefaultTheme())
}
#endif
