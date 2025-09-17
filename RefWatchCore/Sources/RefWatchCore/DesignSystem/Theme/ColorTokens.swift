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
        matchPositive: Color = Color(red: 31 / 255, green: 179 / 255, blue: 106 / 255),
        matchWarning: Color = Color(red: 247 / 255, green: 107 / 255, blue: 53 / 255),
        matchCritical: Color = Color(red: 228 / 255, green: 0 / 255, blue: 43 / 255),
        matchNeutral: Color = Color(red: 242 / 255, green: 199 / 255, blue: 68 / 255),
        accentPrimary: Color = Color(red: 15 / 255, green: 44 / 255, blue: 99 / 255),
        accentSecondary: Color = Color(red: 64 / 255, green: 163 / 255, blue: 211 / 255),
        accentMuted: Color = Color(red: 122 / 255, green: 30 / 255, blue: 58 / 255),
        backgroundPrimary: Color = Color(red: 3 / 255, green: 7 / 255, blue: 17 / 255),
        backgroundSecondary: Color = Color(red: 16 / 255, green: 23 / 255, blue: 42 / 255),
        backgroundElevated: Color = Color(red: 27 / 255, green: 35 / 255, blue: 56 / 255),
        surfaceOverlay: Color = Color.white.opacity(0.08),
        textPrimary: Color = Color.white,
        textSecondary: Color = Color.white.opacity(0.72),
        textInverted: Color = Color(red: 11 / 255, green: 19 / 255, blue: 38 / 255),
        outlineMuted: Color = Color.white.opacity(0.12)
    ) {
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

public extension ColorPalette {
    /// Football South Australia aligned palette (≥4.5:1 contrast for key text on dark surfaces).
    static var footballSA: ColorPalette { ColorPalette() }

    static var standard: ColorPalette { .footballSA }
}
