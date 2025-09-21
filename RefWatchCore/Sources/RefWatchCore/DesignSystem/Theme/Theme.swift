import SwiftUI

public protocol Theme {
    var colors: ColorPalette { get }
    var typography: TypographyScale { get }
    var spacing: SpacingScale { get }
    var components: ComponentStyles { get }
}

public struct DefaultTheme: Theme {
    public let colors: ColorPalette
    public let typography: TypographyScale
    public let spacing: SpacingScale
    public let components: ComponentStyles

    public init(
        colors: ColorPalette = .standard,
        typography: TypographyScale = .standard,
        spacing: SpacingScale = .standard,
        components: ComponentStyles = .standard
    ) {
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.components = components
    }
}

public struct AnyTheme: Theme {
    public let colors: ColorPalette
    public let typography: TypographyScale
    public let spacing: SpacingScale
    public let components: ComponentStyles

    public init(colors: ColorPalette, typography: TypographyScale, spacing: SpacingScale, components: ComponentStyles) {
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.components = components
    }

    public init(theme: some Theme) {
        self.init(
            colors: theme.colors,
            typography: theme.typography,
            spacing: theme.spacing,
            components: theme.components
        )
    }
}

public extension Theme {
    func eraseToAnyTheme() -> AnyTheme { AnyTheme(theme: self) }
}

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AnyTheme = AnyTheme(theme: DefaultTheme())
}

public extension EnvironmentValues {
    var theme: AnyTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func theme(_ theme: some Theme) -> some View {
        environment(\.theme, theme.eraseToAnyTheme())
    }
}
