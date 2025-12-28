import SwiftUI
import Combine
import RefWatchCore

enum ThemeVariant: String, CaseIterable, Identifiable {
  case standard
  case highContrast

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .standard:
      return "Standard"
    case .highContrast:
      return "High Contrast"
    }
  }
}

@MainActor
final class ThemeManager: ObservableObject {
  @Published private(set) var variant: ThemeVariant
  @Published private(set) var theme: AnyTheme

  private let storage: UserDefaults
  private let storageKey: String

  init(
    defaultVariant: ThemeVariant = .standard,
    storage: UserDefaults = .standard,
    storageKey: String = "theme_variant"
  ) {
    self.storage = storage
    self.storageKey = storageKey

    let storedVariant = storage.string(forKey: storageKey).flatMap(ThemeVariant.init(rawValue:))
    let resolvedVariant = storedVariant ?? defaultVariant

    self.variant = resolvedVariant
    self.theme = ThemeFactory.makeTheme(for: resolvedVariant)
  }

  func apply(_ variant: ThemeVariant) {
    guard variant != self.variant else { return }
    self.variant = variant
    self.theme = ThemeFactory.makeTheme(for: variant)
    storage.set(variant.rawValue, forKey: storageKey)
  }

  func reload() {
    theme = ThemeFactory.makeTheme(for: variant)
  }
}

private enum ThemeFactory {
  static func makeTheme(for variant: ThemeVariant) -> AnyTheme {
    switch variant {
    case .standard:
      return makeStandardTheme()
    case .highContrast:
      return makeHighContrastTheme()
    }
  }

  private static func makeStandardTheme() -> AnyTheme {
    AnyTheme(
      colors: ColorPalette.standard,
      typography: makeTypography(
        timerPrimarySize: 48,
        timerSecondarySize: 20,
        timerTertiarySize: 16,
        headlineSize: 24,
        subtitleSize: 18
      ),
      spacing: makeSpacing(stackSpacing: 14),
      components: makeComponents(outlineOpacity: 0.22)
    )
  }

  private static func makeHighContrastTheme() -> AnyTheme {
    let base = ColorPalette.standard
    let highContrastColors = ColorPalette(
      matchPositive: base.matchPositive,
      matchWarning: base.matchWarning,
      matchCritical: base.matchCritical,
      matchNeutral: base.matchNeutral,
      accentPrimary: base.accentPrimary,
      accentSecondary: Color(red: 90 / 255, green: 200 / 255, blue: 250 / 255),
      accentMuted: base.accentMuted,
      backgroundPrimary: base.backgroundPrimary,
      backgroundSecondary: base.backgroundSecondary,
      backgroundElevated: Color(red: 33 / 255, green: 42 / 255, blue: 66 / 255),
      surfaceOverlay: Color.white.opacity(0.16),
      textPrimary: Color.white,
      textSecondary: Color.white.opacity(0.9),
      textInverted: base.textInverted,
      outlineMuted: Color.white.opacity(0.35)
    )

    return AnyTheme(
      colors: highContrastColors,
      typography: makeTypography(
        timerPrimarySize: 50,
        timerSecondarySize: 22,
        timerTertiarySize: 18,
        headlineSize: 26,
        subtitleSize: 19
      ),
      spacing: makeSpacing(stackSpacing: 16),
      components: makeComponents(outlineOpacity: 0.35)
    )
  }

  private static func makeTypography(
    timerPrimarySize: CGFloat,
    timerSecondarySize: CGFloat,
    timerTertiarySize: CGFloat,
    headlineSize: CGFloat,
    subtitleSize: CGFloat
  ) -> TypographyScale {
    TypographyScale(
      timerPrimary: roundedFont(size: timerPrimarySize, weight: .bold, textStyle: .largeTitle, monospaced: true),
      timerSecondary: roundedFont(size: timerSecondarySize, weight: .semibold, textStyle: .title3, monospaced: true),
      timerTertiary: roundedFont(size: timerTertiarySize, weight: .medium, textStyle: .headline, monospaced: true),
      heroTitle: roundedFont(size: headlineSize, weight: .semibold, textStyle: .title2),
      heroSubtitle: roundedFont(size: subtitleSize, weight: .medium, textStyle: .title3),
      cardHeadline: roundedFont(size: 22, weight: .semibold, textStyle: .title3),
      cardMeta: roundedFont(size: 15, weight: .medium, textStyle: .subheadline),
      body: .body,
      label: .headline,
      caption: .footnote,
      button: roundedFont(size: 17, weight: .medium, textStyle: .callout),
      iconAccent: .system(size: 20, weight: .semibold),
      iconSecondary: .system(size: 13, weight: .semibold)
    )
  }

  private static func makeSpacing(stackSpacing: CGFloat) -> SpacingScale {
    SpacingScale(
      xs: 6,
      s: 10,
      m: 14,
      l: 20,
      xl: 28,
      stackSpacing: stackSpacing
    )
  }

  private static func makeComponents(outlineOpacity: Double) -> ComponentStyles {
    ComponentStyles(
      cardCornerRadius: 18,
      chipCornerRadius: 10,
      controlCornerRadius: 12,
      buttonHeight: 52,
      listRowVerticalInset: 8,
      heroCardCornerRadius: 22,
      heroCardHorizontalPadding: 18,
      heroCardVerticalPadding: 20,
      cardShadowRadius: 14,
      cardShadowYOffset: 6,
      cardShadowOpacity: outlineOpacity,
      listVerticalSpacing: 12,
      cardHorizontalPadding: 16
    )
  }
}

private func roundedFont(
  size: CGFloat,
  weight: Font.Weight,
  textStyle: Font.TextStyle,
  monospaced: Bool = false
) -> Font {
  var font = Font.system(textStyle, design: .rounded).weight(weight)
  if monospaced { font = font.monospacedDigit() }
  return font
}
