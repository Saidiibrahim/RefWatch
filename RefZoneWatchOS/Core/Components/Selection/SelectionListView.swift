//
//  SelectionListView.swift
//  RefZoneWatchOS
//
//  Description: Generic selection list component for enum-based options
//  Rule Applied: State management, Code Structure, Swift Best Practices
//

import SwiftUI

/// Generic selection list for enum-based options
struct SelectionListView<T>: View where T: Hashable {
    let title: String
    let options: [T]
    let formatter: (T) -> String
    let onSelect: (T) -> Void
    
    // Optional customization - using enum for list style
    let useCarouselStyle: Bool
    
    /// Primary initializer with custom options and formatter
    init(
        title: String,
        options: [T],
        formatter: @escaping (T) -> String,
        useCarouselStyle: Bool = true,
        onSelect: @escaping (T) -> Void
    ) {
        self.title = title
        self.options = options
        self.formatter = formatter
        self.useCarouselStyle = useCarouselStyle
        self.onSelect = onSelect
    }
    
    /// Convenience initializer for CaseIterable enums with RawValue String
    init(
        title: String,
        useCarouselStyle: Bool = true,
        onSelect: @escaping (T) -> Void
    ) where T: RawRepresentable & CaseIterable, T.RawValue == String {
        self.title = title
        self.options = Array(T.allCases)
        self.formatter = { $0.rawValue }
        self.useCarouselStyle = useCarouselStyle
        self.onSelect = onSelect
    }
    
    var body: some View {
        Group {
            if useCarouselStyle {
                List {
                    ForEach(options, id: \.self) { option in
                        SelectionButton(
                            text: formatter(option),
                            action: { onSelect(option) }
                        )
                    }
                }
                .listStyle(.carousel)
            } else {
                List {
                    ForEach(options, id: \.self) { option in
                        SelectionButton(
                            text: formatter(option),
                            action: { onSelect(option) }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Supporting Views

/// Individual selection button component
private struct SelectionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Support

private enum SampleOption: String, CaseIterable {
    case option1 = "Option 1"
    case option2 = "Option 2"
    case option3 = "Option 3"
}

#Preview {
    NavigationStack {
        SelectionListView<SampleOption>(
            title: "Sample Selection"
        ) { option in
            print("Selected: \(option.rawValue)")
        }
    }
}
