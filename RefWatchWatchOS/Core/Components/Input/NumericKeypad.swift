//
//  NumericKeypad.swift
//  RefWatchWatchOS
//
//  Description: Reusable numeric keypad component for number input across the app
//  Rule Applied: Code Structure, Swift Best Practices
//

import SwiftUI
import RefWatchCore

/// Reusable numeric keypad component for number input scenarios
struct NumericKeypad: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout
    @Binding var numberString: String
    let maxDigits: Int
    let onSubmit: (Int) -> Void
    
    // Configuration options
    let placeholder: String
    let placeholderColor: Color // Customizable color for placeholder text
    
    // Keypad layout - updated to match new design with back button and OK
    private let keypadLayout = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["←", "0", "OK"]  // Back, 0, and OK buttons
    ]
    
    /// Default initializer with common configuration
    init(
        numberString: Binding<String>,
        maxDigits: Int = 2,
        placeholder: String = "0",
        placeholderColor: Color = .secondary, // Default to secondary to indicate placeholder
        onSubmit: @escaping (Int) -> Void
    ) {
        self._numberString = numberString
        self.maxDigits = maxDigits
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        let rowSpacing = layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)
        let columnSpacing = layout.dimension(theme.spacing.s, minimum: theme.spacing.xs)

        VStack(spacing: rowSpacing) {
            // Number display
            Text(numberString.isEmpty ? placeholder : numberString)
                .font(theme.typography.cardMeta)
                // Use placeholder color when there is no input, otherwise primary
                .foregroundStyle(numberString.isEmpty ? placeholderColor : theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacing.xs)
            
            // Keypad grid
            VStack(spacing: rowSpacing) {
                ForEach(keypadLayout, id: \.self) { row in
                    HStack(spacing: columnSpacing) {
                        ForEach(row, id: \.self) { key in
                            KeypadButton(
                                key: key,
                                style: buttonStyle(for: key),
                                action: { handleKeyPress(key) }
                            )
                        }
                    }
                }
            }
        }
        .padding(.bottom, layout.safeAreaBottomPadding)
    }
    
    // MARK: - Private Methods
    
    private func handleKeyPress(_ key: String) {
        switch key {
        case "←":
            // Handle backspace
            if !numberString.isEmpty {
                numberString = String(numberString.dropLast())
            }
        case "OK":
            // Handle submit
            submitNumber()
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            // Handle numeric input - limit to maxDigits
            if numberString.count < maxDigits {
                numberString += key
            }
        default:
            break
        }
    }
    
    private func submitNumber() {
        if let number = Int(numberString), number > 0 {
            onSubmit(number)
        }
    }

    private func buttonStyle(for key: String) -> KeypadButtonStyle {
        switch key {
        case "←", "OK":
            return .action
        default:
            return .number
        }
    }
}

// MARK: - Supporting Views

/// Individual keypad button component
private enum KeypadButtonStyle {
    case number
    case action
}

private struct KeypadButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.watchLayoutScale) private var layout

    let key: String
    let style: KeypadButtonStyle
    let action: () -> Void
    
    var body: some View {
        let baseHeight = layout.dimension(theme.components.buttonHeight, minimum: 44)
        let height = style == .action
            ? layout.dimension(theme.components.buttonHeight * 0.8, minimum: 36)
            : baseHeight
        let outlineColor = style == .action
            ? theme.colors.outlineMuted.opacity(0.6)
            : theme.colors.outlineMuted
        let showBackground = style == .number
        Button(action: action) {
            Text(key)
                .font(theme.typography.cardHeadline)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(minHeight: height)
                .background(
                    Group {
                        if showBackground {
                            Capsule()
                                .fill(theme.colors.backgroundElevated)
                        }
                    }
                )
                .overlay(
                    Group {
                        if showBackground {
                            Capsule()
                                .stroke(outlineColor, lineWidth: 1)
                        }
                    }
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // Provide better accessibility labels for special buttons
    private var accessibilityLabel: String {
        switch key {
        case "←":
            return "Backspace"
        case "OK":
            return "Submit"
        default:
            return key
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var numberString = ""
    
    return VStack(spacing: 20) {
        NumericKeypad(
            numberString: $numberString,
            maxDigits: 2,
            placeholder: "Enter number"
        ) { number in
            print("Number entered: \(number)")
        }
    }
    .padding()
}
