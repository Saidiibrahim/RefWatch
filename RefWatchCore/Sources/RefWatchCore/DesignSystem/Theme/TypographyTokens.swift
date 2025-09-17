import SwiftUI

public struct TypographyScale {
    public let timerPrimary: Font
    public let timerSecondary: Font
    public let timerTertiary: Font
    public let heroTitle: Font
    public let heroSubtitle: Font
    public let body: Font
    public let label: Font
    public let caption: Font
    public let button: Font
    public let iconAccent: Font
    public let iconSecondary: Font

    public init(
        timerPrimary: Font = .system(size: 48, weight: .bold, design: .rounded),
        timerSecondary: Font = .system(size: 36, weight: .bold, design: .rounded),
        timerTertiary: Font = .system(size: 20, weight: .medium, design: .rounded),
        heroTitle: Font = .system(size: 24, weight: .semibold, design: .rounded),
        heroSubtitle: Font = .system(size: 18, weight: .medium, design: .rounded),
        body: Font = .body,
        label: Font = .headline,
        caption: Font = .footnote,
        button: Font = .system(size: 16, weight: .medium),
        iconAccent: Font = .system(size: 18, weight: .semibold),
        iconSecondary: Font = .system(size: 12, weight: .semibold)
    ) {
        self.timerPrimary = timerPrimary
        self.timerSecondary = timerSecondary
        self.timerTertiary = timerTertiary
        self.heroTitle = heroTitle
        self.heroSubtitle = heroSubtitle
        self.body = body
        self.label = label
        self.caption = caption
        self.button = button
        self.iconAccent = iconAccent
        self.iconSecondary = iconSecondary
    }
}

public extension TypographyScale {
    static var standard: TypographyScale { TypographyScale() }
}
