import SwiftUI

public struct SpacingScale {
    public let xs: CGFloat
    public let s: CGFloat
    public let m: CGFloat
    public let l: CGFloat
    public let xl: CGFloat
    /// Default vertical spacing used for stacked card lists (navigation blueprint).
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

    /// Convenience aliases that mirror the layout blueprint naming.
    public var stackXS: CGFloat { xs }
    public var stackSM: CGFloat { s }
    public var stackMD: CGFloat { stackSpacing }
    public var stackLG: CGFloat { l }
    public var stackXL: CGFloat { xl }
}

public extension SpacingScale {
    static var standard: SpacingScale { SpacingScale() }
}
