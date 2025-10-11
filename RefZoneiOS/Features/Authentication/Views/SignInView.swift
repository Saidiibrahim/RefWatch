//
//  SignInView.swift
//  RefZoneiOS
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
                VStack(spacing: 24) {
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
            Text("Sign in to use RefZone on iPhone")
                .font(.title2.bold())
                .foregroundStyle(colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.mode.footnote)
                .font(.subheadline)
                .foregroundStyle(colors.secondaryText)
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
                .foregroundStyle(colors.primaryText)
                .authenticationInputField(colors: colors)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit(submitPrimaryAction)
                .foregroundStyle(colors.primaryText)
                .authenticationInputField(colors: colors)

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
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(colors.accent)
            }

            Text("Signing in keeps RefZone on iPhone and Apple Watch in sync. Your watch works offline and updates when you return here.")
                .font(.footnote)
                .foregroundStyle(colors.secondaryText)
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

    init(theme: AnyTheme, colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            background = theme.colors.backgroundPrimary
            surface = theme.colors.backgroundSecondary
            outline = theme.colors.outlineMuted
            separator = theme.colors.outlineMuted.opacity(0.9)
            primaryText = theme.colors.textPrimary
            secondaryText = theme.colors.textSecondary
            accent = theme.colors.accentSecondary
            primaryActionBackground = theme.colors.accentSecondary
            primaryActionForeground = Color.white
            buttonShadow = Color.black.opacity(0.45)
        default:
            background = Color(uiColor: .systemBackground)
            surface = Color(uiColor: .secondarySystemBackground)
            outline = Color(uiColor: .separator).opacity(0.35)
            separator = Color(uiColor: .separator).opacity(0.6)
            primaryText = Color(uiColor: .label)
            secondaryText = Color(uiColor: .secondaryLabel)
            accent = Color(uiColor: .systemBlue)
            primaryActionBackground = theme.colors.accentSecondary
            primaryActionForeground = Color.white
            buttonShadow = Color.black.opacity(0.12)
        }
    }
}

struct AuthenticationInputFieldModifier: ViewModifier {
    let colors: AuthenticationScreenColors
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colors.outline, lineWidth: 1)
            )
            .shadow(color: colors.buttonShadow.opacity(colorScheme == .dark ? 0 : 0.05), radius: 12, y: 4)
    }
}

extension View {
    func authenticationInputField(colors: AuthenticationScreenColors) -> some View {
        modifier(AuthenticationInputFieldModifier(colors: colors))
    }
}

struct AuthenticationPrimaryButtonStyle: ButtonStyle {
    let colors: AuthenticationScreenColors
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        let background = isEnabled ? colors.primaryActionBackground : colors.primaryActionBackground.opacity(0.45)
        let foreground = isEnabled ? colors.primaryActionForeground : colors.primaryActionForeground.opacity(0.7)
        let border = colors.primaryActionBackground.opacity(isEnabled ? 0.4 : 0.15)
        let shadowOpacity = isEnabled ? (pressed ? 0.20 : 0.28) : 0

        return configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
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
            .foregroundStyle(palette.foreground.opacity(opacity))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.background.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
            let shadowColor = colorScheme == .dark ? Color.black : Color.black.opacity(0.2)
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
