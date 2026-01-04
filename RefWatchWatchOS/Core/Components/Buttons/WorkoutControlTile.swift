import RefWatchCore
import SwiftUI

/// Capsule-style control tile used within workout sessions. Exposes
/// sizing and typography overrides so feature screens can tune for
/// different watch sizes without rewriting layout logic.
struct WorkoutControlTile: View {
  struct Style {
    var circleDiameter: CGFloat = 52
    var iconSize: CGFloat = 22
    var verticalSpacing: CGFloat?
    var titleFont: Font?
    var titleColor: Color?
    var badgeFont: Font?
    var badgeHorizontalPadding: CGFloat = 4
    var badgeVerticalPadding: CGFloat = 3
    var tileVerticalPadding: CGFloat?
    var preferredHeight: CGFloat?
  }

  @Environment(\.theme) private var theme

  let title: String
  let systemImage: String
  let tint: Color
  let foreground: Color
  var badgeText: String?
  var isDisabled: Bool = false
  var isLoading: Bool = false
  var style: Style = .init()
  let action: () -> Void

  private var spacing: CGFloat { self.style.verticalSpacing ?? self.theme.spacing.xs }
  private var titleFont: Font { self.style.titleFont ?? self.theme.typography.cardMeta }
  private var titleColor: Color { self.style.titleColor ?? self.foreground }
  private var badgeFont: Font { self.style.badgeFont ?? .system(size: 12, weight: .semibold, design: .rounded) }
  private var tilePadding: CGFloat { self.style.tileVerticalPadding ?? self.theme.spacing.xs * 0.5 }

  var body: some View {
    Button(action: self.action) {
      VStack(spacing: self.spacing) {
        ZStack {
          Circle()
            .fill(self.tint.opacity(self.isDisabled ? 0.45 : 1.0))
            .frame(width: self.style.circleDiameter, height: self.style.circleDiameter)

          if self.isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(self.foreground.opacity(self.isDisabled ? 0.6 : 1.0))
          } else {
            Image(systemName: self.systemImage)
              .font(.system(size: self.style.iconSize, weight: .semibold))
              .foregroundStyle(self.foreground.opacity(self.isDisabled ? 0.6 : 1.0))
          }
        }
        .overlay(self.badgeOverlay, alignment: .topTrailing)

        Text(self.title)
          .font(self.titleFont)
          .foregroundStyle(self.titleColor.opacity(self.isDisabled ? 0.6 : 1.0))
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
      }
      .frame(maxWidth: .infinity, minHeight: self.tileHeight, alignment: .top)
      .padding(.vertical, self.tilePadding)
      .accessibilityLabel(self.title)
    }
    .buttonStyle(.plain)
    .disabled(self.isDisabled)
  }

  @ViewBuilder
  private var badgeOverlay: some View {
    if let badgeText {
      Text(badgeText)
        .font(self.badgeFont)
        .foregroundStyle(self.theme.colors.backgroundPrimary)
        .padding(.horizontal, self.style.badgeHorizontalPadding)
        .padding(.vertical, self.style.badgeVerticalPadding)
        .background(self.tint.opacity(self.isDisabled ? 0.6 : 1.0), in: Capsule())
        .offset(x: self.style.circleDiameter * 0.2, y: -self.style.circleDiameter * 0.2)
    }
  }

  private var tileHeight: CGFloat {
    if let preferred = style.preferredHeight { return preferred }
    return self.style.circleDiameter + self.spacing + 24 + self.tilePadding * 2
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
      .frame(height: self.preferredHeight)
      .accessibilityHidden(true)
  }

  private var preferredHeight: CGFloat {
    if let preferred = style.preferredHeight { return preferred }
    let spacing = self.style.verticalSpacing ?? self.theme.spacing.xs
    return self.style
      .circleDiameter + spacing + 24 + (self.style.tileVerticalPadding ?? self.theme.spacing.xs * 0.5) * 2
  }
}

#Preview("Workout Control Tiles") {
  VStack(spacing: 8) {
    WorkoutControlTile(
      title: "Pause",
      systemImage: "pause.fill",
      tint: .orange,
      foreground: .black,
      action: {})

    WorkoutControlTile(
      title: "Segment",
      systemImage: "flag.checkered",
      tint: .green,
      foreground: .black,
      badgeText: "3",
      style: .init(circleDiameter: 44, iconSize: 20)) {}
  }
  .theme(DefaultTheme())
}
