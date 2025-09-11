//
//  ActionButton.swift
//  RefWatchWatchOS
//
//  Description: Standalone action button (not for NavigationLinks) with icon and label
//

import SwiftUI

/// Standalone action button (not for NavigationLinks)
struct ActionButton: View {
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
            HStack(spacing: 12) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Label
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Removed padding and background to eliminate grey background/padding
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
