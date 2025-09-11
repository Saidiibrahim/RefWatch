//
//  NavigationLinkButton.swift
//  RefWatchWatchOS
//
//  Description: Reusable NavigationLink wrapper with consistent WatchOS styling
//

import SwiftUI

/// Wrapper for NavigationLink with consistent WatchOS styling
struct NavigationLinkButton<Destination: View>: View {
    let title: String
    let destination: Destination
    let backgroundColor: Color
    let foregroundColor: Color
    let icon: String?
    
    // Default initializer for text-only buttons
    init(
        title: String,
        destination: Destination,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white
    ) {
        self.title = title
        self.destination = destination
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = nil
    }
    
    // Initializer with icon support
    init(
        title: String,
        icon: String,
        destination: Destination,
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white
    ) {
        self.title = title
        self.destination = destination
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = icon
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
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
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Removes default grey background on WatchOS
    }
}

/// Simple NavigationLink wrapper for settings/list rows
struct NavigationLinkRow<Destination: View>: View {
    let title: String
    let value: String?
    let destination: Destination
    
    init(title: String, value: String? = nil, destination: Destination) {
        self.title = title
        self.value = value
        self.destination = destination
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
        }
        .buttonStyle(PlainButtonStyle()) // Removes default grey background
    }
}

/// Icon-based NavigationLink button
struct NavigationIconButton<Destination: View>: View {
    let icon: String
    let color: Color
    let destination: Destination
    let size: CGFloat
    
    init(
        icon: String,
        color: Color = .green,
        size: CGFloat = 40,
        destination: Destination
    ) {
        self.icon = icon
        self.color = color
        self.destination = destination
        self.size = size
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            Image(systemName: icon)
                .font(.system(size: size * 0.6, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color)
                )
        }
        .buttonStyle(PlainButtonStyle()) // Removes default grey background
    }
}

#Preview {
    NavigationStack {
        VStack(spacing: 16) {
            NavigationLinkButton(
                title: "Start Match",
                destination: Text("Destination")
            )
            
            NavigationLinkButton(
                title: "Settings",
                icon: "gear",
                destination: Text("Settings"),
                backgroundColor: .gray
            )
            
            NavigationIconButton(
                icon: "checkmark.circle.fill",
                destination: Text("Confirmed")
            )
            
            NavigationLinkRow(
                title: "Duration",
                value: "90 min",
                destination: Text("Duration Settings")
            )
        }
        .padding()
    }
}
