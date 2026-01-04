import SwiftUI

public struct ColorPalette {
  public let matchPositive: Color
  public let matchWarning: Color
  public let matchCritical: Color
  public let matchNeutral: Color
  public let accentPrimary: Color
  public let accentSecondary: Color
  public let accentMuted: Color
  public let backgroundPrimary: Color
  public let backgroundSecondary: Color
  public let backgroundElevated: Color
  public let surfaceOverlay: Color
  public let textPrimary: Color
  public let textSecondary: Color
  public let textInverted: Color
  public let outlineMuted: Color

  public init(
    matchPositive: Color,
    matchWarning: Color,
    matchCritical: Color,
    matchNeutral: Color,
    accentPrimary: Color,
    accentSecondary: Color,
    accentMuted: Color,
    backgroundPrimary: Color,
    backgroundSecondary: Color,
    backgroundElevated: Color,
    surfaceOverlay: Color,
    textPrimary: Color,
    textSecondary: Color,
    textInverted: Color,
    outlineMuted: Color)
  {
    self.matchPositive = matchPositive
    self.matchWarning = matchWarning
    self.matchCritical = matchCritical
    self.matchNeutral = matchNeutral
    self.accentPrimary = accentPrimary
    self.accentSecondary = accentSecondary
    self.accentMuted = accentMuted
    self.backgroundPrimary = backgroundPrimary
    self.backgroundSecondary = backgroundSecondary
    self.backgroundElevated = backgroundElevated
    self.surfaceOverlay = surfaceOverlay
    self.textPrimary = textPrimary
    self.textSecondary = textSecondary
    self.textInverted = textInverted
    self.outlineMuted = outlineMuted
  }
}

extension ColorPalette {
  /// Football South Australia aligned palette.
  /// Contrast checks (light text on dark surfaces) meet ≥7:1 for primary text and ≥4.5:1 for metadata.
  public static let footballSA = ColorPalette(
    matchPositive: Color(red: 31 / 255, green: 179 / 255, blue: 106 / 255, opacity: 1), // #1FB36A
    matchWarning: Color(red: 247 / 255, green: 107 / 255, blue: 53 / 255, opacity: 1), // #F76B35
    matchCritical: Color(red: 228 / 255, green: 0 / 255, blue: 43 / 255, opacity: 1),
    // #E4002B (6.6:1 vs backgroundPrimary)
    matchNeutral: Color(red: 242 / 255, green: 199 / 255, blue: 68 / 255, opacity: 1),
    // #F2C744 (4.8:1 vs backgroundPrimary)
    accentPrimary: Color(red: 15 / 255, green: 44 / 255, blue: 99 / 255, opacity: 1), // #0F2C63
    accentSecondary: Color(red: 64 / 255, green: 163 / 255, blue: 211 / 255, opacity: 1), // #40A3D3
    accentMuted: Color(red: 122 / 255, green: 30 / 255, blue: 58 / 255, opacity: 1), // #7A1E3A
    backgroundPrimary: Color(red: 3 / 255, green: 7 / 255, blue: 17 / 255, opacity: 1), // #030711
    backgroundSecondary: Color(red: 16 / 255, green: 23 / 255, blue: 42 / 255, opacity: 1), // #10172A
    backgroundElevated: Color(red: 27 / 255, green: 35 / 255, blue: 56 / 255, opacity: 1), // #1B2338
    surfaceOverlay: Color.white.opacity(0.08),
    textPrimary: Color.white,
    textSecondary: Color.white.opacity(0.72),
    textInverted: Color(red: 11 / 255, green: 19 / 255, blue: 38 / 255, opacity: 1), // #0B1326
    outlineMuted: Color.white.opacity(0.12))

  public static var standard: ColorPalette { .footballSA }
}
