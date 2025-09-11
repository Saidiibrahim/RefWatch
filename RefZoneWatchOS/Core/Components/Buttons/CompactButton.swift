//
//  CompactButton.swift
//  RefWatchWatchOS
//
//  Description: Compact button for space-constrained views like WatchOS
//

import SwiftUI

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

#Preview {
    VStack(spacing: 16) {
        CompactButton(
            title: "Compact",
            style: .secondary
        )
        
        CompactButton(
            title: "Primary Compact",
            style: .primary
        )
    }
    .padding()
}
