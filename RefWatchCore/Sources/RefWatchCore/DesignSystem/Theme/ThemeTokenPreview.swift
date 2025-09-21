#if DEBUG
import SwiftUI

struct ThemeTokenPreview: View {
    @Environment(\.theme) private var theme

    private let colorColumns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                colorPaletteSection
                typographySection
                componentSection
            }
            .padding(theme.spacing.l)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Theme Tokens")
    }
}

private extension ThemeTokenPreview {
    var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Text("Colors")
                .font(theme.typography.heroTitle)
                .foregroundStyle(theme.colors.textPrimary)

            LazyVGrid(columns: colorColumns, spacing: 12) {
                ForEach(colorTokens, id: \.label) { token in
                    ThemeColorSwatch(label: token.label, color: token.color(theme.colors))
                }
            }
        }
    }

    var typographySection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("Typography")
                .font(theme.typography.heroTitle)
                .foregroundStyle(theme.colors.textPrimary)

            VStack(alignment: .leading, spacing: theme.spacing.s) {
                typographyRow(label: "Timer Primary", font: theme.typography.timerPrimary, sample: "90:00")
                typographyRow(label: "Timer Secondary", font: theme.typography.timerSecondary, sample: "45:00")
                typographyRow(label: "Card Headline", font: theme.typography.cardHeadline, sample: "Start Match")
                typographyRow(label: "Card Meta", font: theme.typography.cardMeta, sample: "Match options")
                typographyRow(label: "Button", font: theme.typography.button, sample: "Confirm")
            }
            .padding(theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                    .fill(theme.colors.backgroundElevated)
            )
        }
    }

    var componentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("Components")
                .font(theme.typography.heroTitle)
                .foregroundStyle(theme.colors.textPrimary)

            VStack(alignment: .leading, spacing: theme.spacing.s) {
                componentRow(label: "Card Corner Radius", value: "\(Int(theme.components.cardCornerRadius))pt")
                componentRow(label: "List Vertical Spacing", value: "\(Int(theme.components.listVerticalSpacing))pt")
                componentRow(label: "Button Height", value: "\(Int(theme.components.buttonHeight))pt")
            }
            .padding(theme.spacing.m)
            .background(
                RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                    .stroke(theme.colors.outlineMuted)
            )
        }
    }

    func typographyRow(label: String, font: Font, sample: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                Text(sample)
                    .font(font)
                    .foregroundStyle(theme.colors.textPrimary)
            }
            Spacer()
        }
    }

    func componentRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(theme.typography.cardMeta)
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Text(value)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    var colorTokens: [(label: String, color: (ColorPalette) -> Color)] {
        [
            ("Match Positive", { $0.matchPositive }),
            ("Match Warning", { $0.matchWarning }),
            ("Match Critical", { $0.matchCritical }),
            ("Match Neutral", { $0.matchNeutral }),
            ("Accent Primary", { $0.accentPrimary }),
            ("Accent Secondary", { $0.accentSecondary }),
            ("Accent Muted", { $0.accentMuted }),
            ("Background Primary", { $0.backgroundPrimary }),
            ("Background Secondary", { $0.backgroundSecondary }),
            ("Background Elevated", { $0.backgroundElevated }),
            ("Surface Overlay", { $0.surfaceOverlay }),
            ("Text Primary", { $0.textPrimary }),
            ("Text Secondary", { $0.textSecondary }),
            ("Text Inverted", { $0.textInverted }),
            ("Outline Muted", { $0.outlineMuted })
        ]
    }
}

private struct ThemeColorSwatch: View {
    @Environment(\.theme) private var theme
    let label: String
    let color: Color

    init(label: String, color: Color) {
        self.label = label
        self.color = color
    }

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                .frame(height: 56)
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview("Default Theme") {
    NavigationStack {
        ThemeTokenPreview()
    }
    .theme(DefaultTheme())
}
#endif
