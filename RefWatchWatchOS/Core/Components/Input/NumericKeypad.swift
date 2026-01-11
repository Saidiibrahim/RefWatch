//
//  NumericKeypad.swift
//  RefWatchWatchOS
//
//  Description: Reusable numeric keypad component for number input across the app
//  Rule Applied: Code Structure, Swift Best Practices
//

import SwiftUI

/// Reusable numeric keypad component for number input scenarios
struct NumericKeypad: View {
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
        VStack(spacing: 12) {
            // Number display
            Text(numberString.isEmpty ? placeholder : numberString)
                .font(.system(size: 15, weight: .medium))
                // Use placeholder color when there is no input, otherwise primary
                .foregroundColor(numberString.isEmpty ? placeholderColor : .primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            
            // Keypad grid
            VStack(spacing: 8) {
                ForEach(keypadLayout, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            KeypadButton(
                                key: key,
                                action: { handleKeyPress(key) }
                            )
                        }
                    }
                }
            }
        }
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
}

// MARK: - Supporting Views

/// Individual keypad button component
private struct KeypadButton: View {
    let key: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
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
