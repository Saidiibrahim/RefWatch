import SwiftUI

public struct ComponentStyles {
    public let cardCornerRadius: CGFloat
    public let chipCornerRadius: CGFloat
    public let controlCornerRadius: CGFloat
    public let buttonHeight: CGFloat
    public let listRowVerticalInset: CGFloat
    public let heroCardCornerRadius: CGFloat
    public let heroCardHorizontalPadding: CGFloat
    public let heroCardVerticalPadding: CGFloat
    public let cardShadowRadius: CGFloat
    public let cardShadowYOffset: CGFloat
    public let cardShadowOpacity: Double
    public let listVerticalSpacing: CGFloat
    public let cardHorizontalPadding: CGFloat

    public init(
        cardCornerRadius: CGFloat = 20,
        chipCornerRadius: CGFloat = 8,
        controlCornerRadius: CGFloat = 10,
        buttonHeight: CGFloat = 48,
        listRowVerticalInset: CGFloat = 4,
        heroCardCornerRadius: CGFloat = 20,
        heroCardHorizontalPadding: CGFloat = 16,
        heroCardVerticalPadding: CGFloat = 18,
        cardShadowRadius: CGFloat = 12,
        cardShadowYOffset: CGFloat = 4,
        cardShadowOpacity: Double = 0.25,
        listVerticalSpacing: CGFloat = 8,
        cardHorizontalPadding: CGFloat = 12
    ) {
        self.cardCornerRadius = cardCornerRadius
        self.chipCornerRadius = chipCornerRadius
        self.controlCornerRadius = controlCornerRadius
        self.buttonHeight = buttonHeight
        self.listRowVerticalInset = listRowVerticalInset
        self.heroCardCornerRadius = heroCardCornerRadius
        self.heroCardHorizontalPadding = heroCardHorizontalPadding
        self.heroCardVerticalPadding = heroCardVerticalPadding
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowYOffset = cardShadowYOffset
        self.cardShadowOpacity = cardShadowOpacity
        self.listVerticalSpacing = listVerticalSpacing
        self.cardHorizontalPadding = cardHorizontalPadding
    }
}

public extension ComponentStyles {
    static var standard: ComponentStyles { ComponentStyles() }
}
