//
//  SelectionListView.swift
//  RefWatchWatchOS
//
//  Description: Generic selection list component for enum-based options
//  Rule Applied: State management, Code Structure, Swift Best Practices
//

import RefWatchCore
import SwiftUI

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
    onSelect: @escaping (T) -> Void)
  {
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
    onSelect: @escaping (T) -> Void) where T: RawRepresentable & CaseIterable, T.RawValue == String
  {
    self.title = title
    self.options = Array(T.allCases)
    self.formatter = { $0.rawValue }
    self.useCarouselStyle = useCarouselStyle
    self.onSelect = onSelect
  }

  var body: some View {
    self.listWithStyle
      .scrollContentBackground(.hidden)
      .padding(.vertical, self.theme.components.listRowVerticalInset)
      .background(self.theme.colors.backgroundPrimary)
      .navigationTitle(self.title)
  }

  @ViewBuilder
  private var listWithStyle: some View {
    if self.useCarouselStyle {
      self.listContent
        .listStyle(.carousel)
    } else {
      self.listContent
        .listStyle(.plain)
    }
  }

  private var listContent: some View {
    List {
      ForEach(self.options, id: \.self) { option in
        Button(action: { self.onSelect(option) }, label: {
          ThemeCardContainer(role: .secondary, minHeight: self.theme.components.buttonHeight) {
            Text(self.formatter(option))
              .font(self.theme.typography.cardHeadline)
              .foregroundStyle(self.theme.colors.textPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        })
        .buttonStyle(.plain)
        .listRowInsets(self.rowInsets)
        .listRowBackground(Color.clear)
      }
    }
  }

  private var rowInsets: EdgeInsets {
    EdgeInsets(
      top: self.theme.components.listRowVerticalInset,
      leading: 0,
      bottom: self.theme.components.listRowVerticalInset,
      trailing: 0)
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
      title: "Sample Selection")
    { option in
      print("Selected: \(option.rawValue)")
    }
  }
  .theme(DefaultTheme())
}
