//
//  CustomButton.swift
//  RefWatch Watch App
//
//  Description: Enhanced reusable button components for consistent WatchOS styling
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Compact button for space-constrained views like WatchOS
struct CompactButton: View {
    let title: String
    let style: CustomButton.ButtonStyle
    
    init(title: String, style: CustomButton.ButtonStyle = .secondary) {
        self.title = title
        self.style = style
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(textColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 32) // Smaller minimum height for compact views
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
    }
    
    // Determine colors based on style
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .blue
        case .secondary:
            return .gray.opacity(0.2)
        case .destructive:
            return .red
        case .accent:
            return .green
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .destructive, .accent:
            return .white
        case .secondary:
            return .primary
        }
    }
}

/// Circular icon button for quick actions
struct IconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    
    init(
        icon: String,
        color: Color = .blue,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color)
                )
        }
        .buttonStyle(PlainButtonStyle())
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
        
        ActionButton(
            title: "Action Button",
            icon: "gear"
        ) {
            print("Action tapped")
        }
        
        CompactButton(
            title: "Compact",
            style: .secondary
        )
        
        IconButton(
            icon: "checkmark",
            color: .green
        ) {
            print("Icon tapped")
        }
    }
    .padding()
}
