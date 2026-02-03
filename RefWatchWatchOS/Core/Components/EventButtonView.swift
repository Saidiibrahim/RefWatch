// EventButtonView.swift
// Description: Circular button component for match events with icon and label below

import SwiftUI
import RefWatchCore

struct EventButtonView: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let icon: String
    let color: Color
    let label: String
    let action: (() -> Void)?
    let isNavigationLabel: Bool

    init(icon: String, color: Color, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.label = label
        self.action = action
        self.isNavigationLabel = false
    }

    init(icon: String, color: Color, label: String, isNavigationLabel: Bool = true) {
        self.icon = icon
        self.color = color
        self.label = label
        self.action = nil
        self.isNavigationLabel = isNavigationLabel
    }

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            controlBody

            Text(label)
                .font(theme.typography.cardMeta.weight(.semibold))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .frame(maxWidth: layout.dimension(80, minimum: 60))
        }
        .accessibilityLabel(Text(label))
    }

    @ViewBuilder
    private var controlBody: some View {
        let size = layout.eventButtonSize
        let cornerRadius = theme.components.controlCornerRadius
        let content = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color.opacity(0.3)) // Increased from 0.18 to 0.3 for better visibility
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color.opacity(0.8), lineWidth: 1.5) // Increased from 0.65 to 0.8 for better visibility
            )
            .frame(width: size, height: size)
            .overlay(iconContent)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        if isNavigationLabel || action == nil {
            content
        } else if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
        }
    }

    private var iconContent: some View {
        Group {
            if icon == "square.fill" {
                Rectangle()
                    .fill(color)
                    .frame(width: layout.dimension(24, minimum: 18), height: layout.dimension(24, minimum: 18))
            } else {
                Image(systemName: icon)
                    .font(.system(size: layout.eventIconSize, weight: .medium))
                    .foregroundStyle(labelColor)
            }
        }
    }

    private var labelColor: Color {
        switch color {
        case .yellow:
            return theme.colors.textPrimary
        case .red, .blue, .green:
            return theme.colors.textPrimary
        default:
            return theme.colors.textPrimary
        }
    }
}
