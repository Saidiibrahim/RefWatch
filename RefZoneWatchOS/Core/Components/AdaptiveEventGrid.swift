import SwiftUI
import RefWatchCore

struct AdaptiveEventGridItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let label: String
    let destination: AnyView
    let onTap: (() -> Void)?

    init(icon: String, color: Color, label: String, onTap: (() -> Void)? = nil, @ViewBuilder destination: () -> some View) {
        self.icon = icon
        self.color = color
        self.label = label
        self.destination = AnyView(destination())
        self.onTap = onTap
    }
}

struct AdaptiveEventGrid: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let items: [AdaptiveEventGridItem]

    var body: some View {
        Group {
            switch layout.eventButtonLayout {
            case .compactVertical:
                compactVerticalLayout
            case .standardGrid, .expandedGrid:
                standardGridLayout
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var compactVerticalLayout: some View {
        VStack(spacing: verticalSpacing) {
            ForEach(Array(compactRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: horizontalSpacing) {
                    ForEach(row) { item in
                        eventButton(for: item)
                    }
                }
            }
        }
    }

    private var standardGridLayout: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: max(layout.eventGridColumns, 1)),
            spacing: gridSpacing
        ) {
            ForEach(items) { item in
                eventButton(for: item)
            }
        }
    }

    private var compactRows: [[AdaptiveEventGridItem]] {
        let chunkSize = max(layout.eventGridColumns, 1)
        return stride(from: 0, to: items.count, by: chunkSize).map { index in
            Array(items[index..<min(index + chunkSize, items.count)])
        }
    }

    private var verticalSpacing: CGFloat {
        layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)
    }

    private var horizontalSpacing: CGFloat {
        layout.category == .compact ? layout.dimension(theme.spacing.s, minimum: 6) : gridSpacing
    }

    private var gridSpacing: CGFloat {
        switch layout.category {
        case .compact:
            return layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)
        case .standard:
            return layout.dimension(theme.spacing.m, minimum: theme.spacing.s)
        case .expanded:
            return layout.dimension(theme.spacing.l, minimum: theme.spacing.m)
        }
    }

    private func eventButton(for item: AdaptiveEventGridItem) -> some View {
        NavigationLink(destination: item.destination) {
            EventButtonView(
                icon: item.icon,
                color: item.color,
                label: item.label,
                isNavigationLabel: true
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded { item.onTap?() }
        )
    }
}
