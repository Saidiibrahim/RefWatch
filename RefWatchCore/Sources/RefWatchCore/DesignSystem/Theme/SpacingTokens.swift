import SwiftUI

public struct SpacingScale {
    public let xs: CGFloat
    public let s: CGFloat
    public let m: CGFloat
    public let l: CGFloat
    public let xl: CGFloat
    public let stackSpacing: CGFloat

    public init(
        xs: CGFloat = 4,
        s: CGFloat = 8,
        m: CGFloat = 12,
        l: CGFloat = 16,
        xl: CGFloat = 24,
        stackSpacing: CGFloat = 12
    ) {
        self.xs = xs
        self.s = s
        self.m = m
        self.l = l
        self.xl = xl
        self.stackSpacing = stackSpacing
    }
}

public extension SpacingScale {
    static var standard: SpacingScale { SpacingScale() }
}
