//
//  ActionGridItem.swift
//  RefZoneWatchOS
//
//  Description: Grid item component with circular icon and text label for action sheets
//

import SwiftUI

/// Grid item component with circular icon and text label for action sheets
struct ActionGridItem: View {
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
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: expandHorizontally ? .infinity : nil, minHeight: 72)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(showBackground ? Color.gray.opacity(0.1) : Color.clear) // Conditional background
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
