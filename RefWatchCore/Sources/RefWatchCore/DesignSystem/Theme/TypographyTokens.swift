import SwiftUI

public struct TypographyScale {
    public let timerPrimary: Font
    public let timerSecondary: Font
    public let timerTertiary: Font
    public let heroTitle: Font
    public let heroSubtitle: Font
    public let cardHeadline: Font
    public let cardMeta: Font
    public let body: Font
    public let label: Font
    public let caption: Font
    public let button: Font
    public let iconAccent: Font
    public let iconSecondary: Font

    public init(
        timerPrimary: Font = roundedFont(size: 52, weight: .bold, textStyle: .largeTitle, monospaced: true),
        timerSecondary: Font = roundedFont(size: 24, weight: .semibold, textStyle: .title3, monospaced: true),
        timerTertiary: Font = roundedFont(size: 18, weight: .medium, textStyle: .headline, monospaced: true),
        heroTitle: Font = roundedFont(size: 24, weight: .semibold, textStyle: .title2),
        heroSubtitle: Font = roundedFont(size: 18, weight: .medium, textStyle: .title3),
        cardHeadline: Font = roundedFont(size: 22, weight: .semibold, textStyle: .title3),
        cardMeta: Font = roundedFont(size: 15, weight: .medium, textStyle: .subheadline),
        body: Font = .body,
        label: Font = .headline,
        caption: Font = .footnote,
        button: Font = roundedFont(size: 16, weight: .medium, textStyle: .callout),
        iconAccent: Font = .system(size: 18, weight: .semibold),
        iconSecondary: Font = .system(size: 12, weight: .semibold)
    ) {
        self.timerPrimary = timerPrimary
        self.timerSecondary = timerSecondary
        self.timerTertiary = timerTertiary
        self.heroTitle = heroTitle
        self.heroSubtitle = heroSubtitle
        self.cardHeadline = cardHeadline
        self.cardMeta = cardMeta
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

@usableFromInline
func roundedFont(
    size: CGFloat,
    weight: Font.Weight,
    textStyle: Font.TextStyle,
    monospaced: Bool = false
) -> Font {
    var font = Font.system(textStyle, design: .rounded).weight(weight)
    if monospaced { font = font.monospacedDigit() }
    return font
}
