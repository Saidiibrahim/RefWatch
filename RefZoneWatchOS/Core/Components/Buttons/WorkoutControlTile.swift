import SwiftUI
import RefWatchCore

/// Capsule-style control tile used within workout sessions. Exposes
/// sizing and typography overrides so feature screens can tune for
/// different watch sizes without rewriting layout logic.
struct WorkoutControlTile: View {
  struct Style {
    var circleDiameter: CGFloat = 52
    var iconSize: CGFloat = 22
    var verticalSpacing: CGFloat? = nil
    var titleFont: Font? = nil
    var titleColor: Color? = nil
    var badgeFont: Font? = nil
    var badgeHorizontalPadding: CGFloat = 4
    var badgeVerticalPadding: CGFloat = 3
    var tileVerticalPadding: CGFloat? = nil
    var preferredHeight: CGFloat? = nil
  }

  @Environment(\.theme) private var theme

  let title: String
  let systemImage: String
  let tint: Color
  let foreground: Color
  var badgeText: String? = nil
  var isDisabled: Bool = false
  var isLoading: Bool = false
  var style: Style = Style()
  let action: () -> Void

  private var spacing: CGFloat { style.verticalSpacing ?? theme.spacing.xs }
  private var titleFont: Font { style.titleFont ?? theme.typography.cardMeta }
  private var titleColor: Color { style.titleColor ?? foreground }
  private var badgeFont: Font { style.badgeFont ?? .system(size: 12, weight: .semibold, design: .rounded) }
  private var tilePadding: CGFloat { style.tileVerticalPadding ?? theme.spacing.xs * 0.5 }

  var body: some View {
    Button(action: action) {
      VStack(spacing: spacing) {
        ZStack {
          Circle()
            .fill(tint.opacity(isDisabled ? 0.45 : 1.0))
            .frame(width: style.circleDiameter, height: style.circleDiameter)

          if isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(foreground.opacity(isDisabled ? 0.6 : 1.0))
          } else {
            Image(systemName: systemImage)
              .font(.system(size: style.iconSize, weight: .semibold))
              .foregroundStyle(foreground.opacity(isDisabled ? 0.6 : 1.0))
          }
        }
        .overlay(badgeOverlay, alignment: .topTrailing)

        Text(title)
          .font(titleFont)
          .foregroundStyle(titleColor.opacity(isDisabled ? 0.6 : 1.0))
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .frame(maxWidth: .infinity, minHeight: tileHeight, alignment: .top)
      .padding(.vertical, tilePadding)
      .accessibilityLabel(title)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }

  @ViewBuilder
  private var badgeOverlay: some View {
    if let badgeText {
      Text(badgeText)
        .font(badgeFont)
        .foregroundStyle(theme.colors.backgroundPrimary)
        .padding(.horizontal, style.badgeHorizontalPadding)
        .padding(.vertical, style.badgeVerticalPadding)
        .background(tint.opacity(isDisabled ? 0.6 : 1.0), in: Capsule())
        .offset(x: style.circleDiameter * 0.2, y: -style.circleDiameter * 0.2)
    }
  }

  private var tileHeight: CGFloat {
    if let preferred = style.preferredHeight { return preferred }
    return style.circleDiameter + spacing + 24 + tilePadding * 2
  }
}

struct WorkoutControlTilePlaceholder: View {
  let style: WorkoutControlTile.Style
  @Environment(\.theme) private var theme

  init(style: WorkoutControlTile.Style = WorkoutControlTile.Style()) {
    self.style = style
  }

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: preferredHeight)
      .accessibilityHidden(true)
  }

  private var preferredHeight: CGFloat {
    if let preferred = style.preferredHeight { return preferred }
    let spacing = style.verticalSpacing ?? theme.spacing.xs
    return style.circleDiameter + spacing + 24 + (style.tileVerticalPadding ?? theme.spacing.xs * 0.5) * 2
  }
}

#Preview("Workout Control Tiles") {
  VStack(spacing: 8) {
    WorkoutControlTile(
      title: "Pause",
      systemImage: "pause.fill",
      tint: .orange,
      foreground: .black,
      action: {}
    )

    WorkoutControlTile(
      title: "Segment",
      systemImage: "flag.checkered",
      tint: .green,
      foreground: .black,
      badgeText: "3",
      style: .init(circleDiameter: 44, iconSize: 20)
    ) { }
  }
  .theme(DefaultTheme())
}
