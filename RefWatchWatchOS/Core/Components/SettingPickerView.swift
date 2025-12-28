import SwiftUI
import Foundation

// Generic picker view for match settings
struct SettingPickerView<T: Hashable>: View {
    let title: String
    let values: [T]
    @Binding var selection: T
    let formatter: (T) -> String
    
    // Add explicit View conformance by making values identifiable
    private var identifiableValues: [IdentifiableValue<T>] {
        values.map { IdentifiableValue(value: $0) }
    }
    
    var body: some View {
        List {
            ForEach(identifiableValues) { item in
                Button(action: { selection = item.value }) {
                    HStack {
                        Text(formatter(item.value))
                        Spacer()
                        if item.value == selection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

// Helper struct to make values identifiable
private struct IdentifiableValue<T: Hashable>: Identifiable {
    let id = UUID()
    let value: T
} 