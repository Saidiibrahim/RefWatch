// EventButtonView.swift
// Description: Circular button component for match events with icon and label below

import SwiftUI

struct EventButtonView: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                // Icon only, no background
                if icon == "square.fill" {
                    Rectangle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
            }
            // Keep the touch target circular and larger than the visual element
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        }
    }
} 