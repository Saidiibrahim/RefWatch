//
//  CustomButton.swift
//  RefWatchWatchOS
//
//  Description: Enhanced button component optimized for WatchOS with multiple style options
//

import SwiftUI

/// Enhanced button component optimized for WatchOS
struct CustomButton: View {
    let title: String
    let icon: String?
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case accent
    }
    
    // Primary initializer with all options
    init(
        title: String,
        icon: String? = nil,
        backgroundColor: Color? = nil,
        foregroundColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        style: ButtonStyle = .primary
    ) {
        self.title = title
        self.icon = icon
        self.cornerRadius = cornerRadius
        self.style = style
        
        // Set colors based on style if not provided
        switch style {
        case .primary:
            self.backgroundColor = backgroundColor ?? .blue
            self.foregroundColor = foregroundColor ?? .white
        case .secondary:
            self.backgroundColor = backgroundColor ?? .gray.opacity(0.2)
            self.foregroundColor = foregroundColor ?? .primary
        case .destructive:
            self.backgroundColor = backgroundColor ?? .red
            self.foregroundColor = foregroundColor ?? .white
        case .accent:
            self.backgroundColor = backgroundColor ?? .green
            self.foregroundColor = foregroundColor ?? .white
        }
    }
    
    // Simple initializer for backward compatibility
    init(title: String) {
        self.title = title
        self.icon = nil
        self.backgroundColor = .blue
        self.foregroundColor = .white
        self.cornerRadius = 12
        self.style = .primary
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(foregroundColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44) // Minimum touch target for accessibility
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        CustomButton(title: "Primary Button")
        
        CustomButton(
            title: "Secondary",
            style: .secondary
        )
        
        CustomButton(
            title: "With Icon",
            icon: "play.circle.fill",
            style: .accent
        )
    }
    .padding()
}
