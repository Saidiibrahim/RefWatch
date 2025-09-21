//
//  ActionGridItem.swift
//  RefZoneWatchOS
//
//  Description: Grid item component with circular icon and text label for action sheets
//

import SwiftUI
import RefWatchCore

/// Grid item component with circular icon and text label for action sheets
struct ActionGridItem: View {
    @Environment(\.theme) private var theme

    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var expandHorizontally: Bool = true
    var showBackground: Bool = true // Add background control parameter
    
    init(
        title: String,
        icon: String,
        color: Color,
        expandHorizontally: Bool = true,
        showBackground: Bool = true, // Default to showing background
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.expandHorizontally = expandHorizontally
        self.showBackground = showBackground
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.xs) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(theme.typography.iconAccent)
                        .foregroundStyle(theme.colors.textInverted)
                }

                Text(title)
                    .font(theme.typography.cardMeta)
                    .foregroundStyle(theme.colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: expandHorizontally ? .infinity : nil, minHeight: 72)
            .padding(.vertical, theme.spacing.s)
            .padding(.horizontal, theme.spacing.s)
            .background(
                RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
                    .fill(showBackground ? theme.colors.surfaceOverlay : Color.clear) // Conditional background
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ActionGridItem(
            title: "Match Log",
            icon: "list.bullet",
            color: .blue
        ) {
            print("Match Log tapped")
        }
        
        ActionGridItem(
            title: "Options",
            icon: "ellipsis.circle",
            color: .gray
        ) {
            print("Options tapped")
        }
        
        ActionGridItem(
            title: "End Half",
            icon: "checkmark.circle",
            color: .green,
            expandHorizontally: false
        ) {
            print("End Half tapped")
        }
    }
    .padding()
}
