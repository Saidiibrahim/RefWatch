// Reason for changes: We fill this file with actual code for handling settings, using a SettingsViewModel.
// Debug logs and comments for clarity (rule: DebugLogging).
// We pass the existing view model (rule: PropWrap).

import SwiftUI

@Observable final class SettingsScreenViewModel {
    // Using zod for potential type validation - Hypothetical usage
    // let settingsSchema = z.object(["exampleSetting": z.boolean()])

    var settingsViewModel = SettingsViewModel()

    func toggleExampleSetting() {
        print("[DEBUG] Toggling exampleSetting to \(!settingsViewModel.exampleSetting)")
        settingsViewModel.exampleSetting.toggle()
    }
}

struct SettingsView: View {
    let model: SettingsScreenViewModel

    var body: some View {
        VStack {
            Text("Settings").font(.headline).padding()

            Toggle(isOn: Binding(
                get: { model.settingsViewModel.exampleSetting },
                set: { _ in model.toggleExampleSetting() }
            )) {
                Text("Example Setting")
            }
            .padding()
        }
        .navigationTitle("Settings")
    }
}
