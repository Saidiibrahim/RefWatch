//
//  IconButton.swift
//  RefZoneWatchOS
//
//  Description: Circular icon button for quick actions
//

import SwiftUI

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
        IconButton(
            icon: "checkmark",
            color: .green
        ) {
            print("Icon tapped")
        }
        
        IconButton(
            icon: "xmark",
            color: .red,
            size: 60
        ) {
            print("Large icon tapped")
        }
    }
    .padding()
}
