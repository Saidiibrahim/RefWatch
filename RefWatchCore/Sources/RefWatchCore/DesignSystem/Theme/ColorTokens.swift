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
        matchPositive: Color = Color.green,
        matchWarning: Color = Color.orange,
        matchCritical: Color = Color.red,
        matchNeutral: Color = Color.yellow,
        accentPrimary: Color = Color.blue,
        accentSecondary: Color = Color.cyan,
        accentMuted: Color = Color.gray,
        backgroundPrimary: Color = Color.black,
        backgroundSecondary: Color = Color.gray.opacity(0.2),
        backgroundElevated: Color = Color.gray.opacity(0.1),
        surfaceOverlay: Color = Color.white.opacity(0.08),
        textPrimary: Color = Color.primary,
        textSecondary: Color = Color.secondary,
        textInverted: Color = Color.white,
        outlineMuted: Color = Color.white.opacity(0.2)
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
    static var standard: ColorPalette { ColorPalette() }
}
