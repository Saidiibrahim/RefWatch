//
//  ActionButton.swift
//  RefZoneWatchOS
//
//  Description: Standalone action button (not for NavigationLinks) with icon and label
//

import SwiftUI
import RefWatchCore

/// Standalone action button (not for NavigationLinks)
struct ActionButton: View {
    @Environment(\.theme) private var theme

    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        color: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.m) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(theme.typography.iconAccent)
                        .foregroundStyle(theme.colors.textInverted)
                }

                // Label
                Text(title)
                    .font(theme.typography.cardHeadline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        ActionButton(
            title: "Action Button",
            icon: "gear"
        ) {
            print("Action tapped")
        }
        
        ActionButton(
            title: "Settings",
            icon: "gear",
            color: .green
        ) {
            print("Settings tapped")
        }
    }
    .padding()
}
