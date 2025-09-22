//
//  IconButton.swift
//  RefZoneWatchOS
//
//  Description: Circular icon button for quick actions
//

import SwiftUI
import RefWatchCore

/// Circular icon button for quick actions
struct IconButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let icon: String
    let color: Color
    private let explicitDiameter: CGFloat?
    let action: () -> Void

    init(
        icon: String,
        color: Color = .blue,
        size: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.explicitDiameter = size
        self.action = action
    }

    var body: some View {
        let diameter = explicitDiameter ?? layout.iconButtonDiameter
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: diameter * 0.48, weight: .semibold))
                .foregroundStyle(theme.colors.textInverted)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle()
                        .fill(color)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(icon.accessibilityLabelFallback))
    }
}

private extension String {
    var accessibilityLabelFallback: String {
        switch self {
        case "checkmark.circle.fill":
            return "Confirm"
        case "xmark.circle.fill":
            return "Cancel"
        default:
            return self
        }
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
