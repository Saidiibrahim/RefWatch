// EventButtonView.swift
// Description: Circular button component for match events with icon and label below

import SwiftUI

struct EventButtonView: View {
    let icon: String
    let color: Color
    let label: String
    let action: (() -> Void)?
    let isNavigationLabel: Bool
    
    // Default initializer for standalone buttons
    init(icon: String, color: Color, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.label = label
        self.action = action
        self.isNavigationLabel = false
    }
    
    // Initializer for NavigationLink labels
    init(icon: String, color: Color, label: String, isNavigationLabel: Bool = true) {
        self.icon = icon
        self.color = color
        self.label = label
        self.action = nil
        self.isNavigationLabel = isNavigationLabel
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if isNavigationLabel {
                // Just the content without Button wrapper for NavigationLink
                iconContent
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color, lineWidth: 2)
                    )
            } else {
                // Wrap in Button for standalone actions
                Button(action: action ?? {}) {
                    iconContent
                }
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color, lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor)
        }
    }
    
    @ViewBuilder
    private var iconContent: some View {
        // Icon with expanded visual background
        if icon == "square.fill" {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(textColor)
        }
    }
    
    // Determine text color for optimal contrast across all color schemes
    private var textColor: Color {
        switch color {
        case .yellow:
            // Use adaptive color for yellow - dark text in light mode, light text in dark mode
            return Color.primary
        case .red, .blue, .green:
            // Dark colors work well with white text in all modes
            return .white
        default:
            // For other colors, use adaptive primary color
            return Color.primary
        }
    }
} 