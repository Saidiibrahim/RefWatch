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

    public init(
        cardCornerRadius: CGFloat = 12,
        chipCornerRadius: CGFloat = 8,
        controlCornerRadius: CGFloat = 10,
        buttonHeight: CGFloat = 48,
        listRowVerticalInset: CGFloat = 4,
        heroCardCornerRadius: CGFloat = 20,
        heroCardHorizontalPadding: CGFloat = 16,
        heroCardVerticalPadding: CGFloat = 18
    ) {
        self.cardCornerRadius = cardCornerRadius
        self.chipCornerRadius = chipCornerRadius
        self.controlCornerRadius = controlCornerRadius
        self.buttonHeight = buttonHeight
        self.listRowVerticalInset = listRowVerticalInset
        self.heroCardCornerRadius = heroCardCornerRadius
        self.heroCardHorizontalPadding = heroCardHorizontalPadding
        self.heroCardVerticalPadding = heroCardVerticalPadding
    }
}

public extension ComponentStyles {
    static var standard: ComponentStyles { ComponentStyles() }
}
