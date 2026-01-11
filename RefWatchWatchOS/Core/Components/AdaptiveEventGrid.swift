import RefWatchCore
import SwiftUI

struct AdaptiveEventGridItem: Identifiable {
  /// Stable identifier to prevent NavigationLink invalidation during recomposition
  let id: String
  let icon: String
  let color: Color
  let label: String
  let destination: AnyView?
  let onTap: (() -> Void)?

  /// Initialize with a navigation destination
  init(
    id: String,
    icon: String,
    color: Color,
    label: String,
    onTap: (() -> Void)? = nil,
    @ViewBuilder destination: () -> some View)
  {
    self.id = id
    self.icon = icon
    self.color = color
    self.label = label
    self.destination = AnyView(destination())
    self.onTap = onTap
  }

  /// Initialize as a tap-only button (no navigation)
  init(id: String, icon: String, color: Color, label: String, onTap: @escaping () -> Void) {
    self.id = id
    self.icon = icon
    self.color = color
    self.label = label
    self.destination = nil
    self.onTap = onTap
  }
}

struct AdaptiveEventGrid: View {
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  let items: [AdaptiveEventGridItem]

  var body: some View {
    Group {
      switch self.layout.eventButtonLayout {
      case .compactVertical:
        self.compactVerticalLayout
      case .standardGrid, .expandedGrid:
        self.standardGridLayout
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var compactVerticalLayout: some View {
    VStack(spacing: self.verticalSpacing) {
      ForEach(Array(self.compactRows.enumerated()), id: \.offset) { _, row in
        HStack(spacing: self.horizontalSpacing) {
          ForEach(row) { item in
            self.eventButton(for: item)
          }
        }
      }
    }
  }

  private var standardGridLayout: some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: gridSpacing),
      count: max(layout.eventGridColumns, 1))
    return LazyVGrid(columns: columns, spacing: self.gridSpacing) {
      ForEach(self.items) { item in
        self.eventButton(for: item)
      }
    }
  }

  private var compactRows: [[AdaptiveEventGridItem]] {
    let chunkSize = max(layout.eventGridColumns, 1)
    return stride(from: 0, to: self.items.count, by: chunkSize).map { index in
      Array(self.items[index..<min(index + chunkSize, self.items.count)])
    }
  }

  private var verticalSpacing: CGFloat {
    self.layout.dimension(self.theme.spacing.s, minimum: self.theme.spacing.xs)
  }

  private var horizontalSpacing: CGFloat {
    self.layout.category == .compact ? self.layout.dimension(self.theme.spacing.s, minimum: 6) : self.gridSpacing
  }

  private var gridSpacing: CGFloat {
    switch self.layout.category {
    case .compact:
      self.layout.dimension(self.theme.spacing.s, minimum: self.theme.spacing.xs)
    case .standard:
      self.layout.dimension(self.theme.spacing.m, minimum: self.theme.spacing.s)
    case .expanded:
      self.layout.dimension(self.theme.spacing.l, minimum: self.theme.spacing.m)
    }
  }

  @ViewBuilder
  private func eventButton(for item: AdaptiveEventGridItem) -> some View {
    if let destination = item.destination {
      // Navigation button
      NavigationLink(destination: destination) {
        EventButtonView(
          icon: item.icon,
          color: item.color,
          label: item.label,
          isNavigationLabel: true)
      }
      .buttonStyle(.plain)
      .simultaneousGesture(
        TapGesture().onEnded { item.onTap?() })
    } else {
      // Tap-only button
      Button(action: { item.onTap?() }, label: {
        EventButtonView(
          icon: item.icon,
          color: item.color,
          label: item.label,
          isNavigationLabel: false)
      })
      .buttonStyle(.plain)
    }
  }
}
