import Foundation
import SwiftUI

// Generic picker view for match settings
struct SettingPickerView<T: Hashable>: View {
  let title: String
  let values: [T]
  @Binding var selection: T
  let formatter: (T) -> String

  // Add explicit View conformance by making values identifiable
  private var identifiableValues: [IdentifiableValue<T>] {
    self.values.map { IdentifiableValue(value: $0) }
  }

  var body: some View {
    List {
      ForEach(self.identifiableValues) { item in
        Button(action: { self.selection = item.value }, label: {
          HStack {
            Text(self.formatter(item.value))
            Spacer()
            if item.value == self.selection {
              Image(systemName: "checkmark")
                .foregroundColor(.green)
            }
          }
        })
      }
    }
    .navigationTitle(self.title)
  }
}

// Helper struct to make values identifiable
private struct IdentifiableValue<T: Hashable>: Identifiable {
  let id = UUID()
  let value: T
}
