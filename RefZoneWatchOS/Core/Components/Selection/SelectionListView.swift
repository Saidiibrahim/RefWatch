//
//  SelectionListView.swift
//  RefZoneWatchOS
//
//  Description: Generic selection list component for enum-based options
//  Rule Applied: State management, Code Structure, Swift Best Practices
//

import SwiftUI
import RefWatchCore

/// Generic selection list for enum-based options
struct SelectionListView<T>: View where T: Hashable {
  @Environment(\.theme) private var theme

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
    listWithStyle
      .scrollContentBackground(.hidden)
      .padding(.vertical, theme.components.listRowVerticalInset)
      .background(theme.colors.backgroundPrimary)
      .navigationTitle(title)
  }

  @ViewBuilder
  private var listWithStyle: some View {
    if useCarouselStyle {
      listContent
        .listStyle(.carousel)
    } else {
      listContent
        .listStyle(.plain)
    }
  }

  private var listContent: some View {
    List {
      ForEach(options, id: \.self) { option in
        Button(action: { onSelect(option) }) {
          ThemeCardContainer(role: .secondary, minHeight: theme.components.buttonHeight) {
            Text(formatter(option))
              .font(theme.typography.cardHeadline)
              .foregroundStyle(theme.colors.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .buttonStyle(.plain)
        .listRowInsets(rowInsets)
        .listRowBackground(Color.clear)
      }
    }
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: theme.components.listRowVerticalInset,
      leading: 0,
      bottom: theme.components.listRowVerticalInset,
      trailing: 0
    )
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
  .theme(DefaultTheme())
}
