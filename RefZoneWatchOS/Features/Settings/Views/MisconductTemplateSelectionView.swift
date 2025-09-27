//
//  MisconductTemplateSelectionView.swift
//  RefZoneWatchOS
//
//  Allows the referee to pick a misconduct template for card reasons.
//

import SwiftUI
import RefWatchCore

struct MisconductTemplateSelectionView: View {
    @Bindable var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SelectionListView(
            title: "Misconduct Template",
            options: settingsViewModel.misconductTemplates,
            formatter: { template in
                label(for: template)
            }
        ) { template in
            settingsViewModel.updateMisconductTemplate(id: template.id)
            dismiss()
        }
    }

    private func label(for template: MisconductTemplate) -> String {
        let base = template.displayName
        if template.id == settingsViewModel.settings.selectedMisconductTemplateID {
            return "\(base) • Current"
        }
        return base
    }
}

#Preview {
    NavigationStack {
        MisconductTemplateSelectionView(settingsViewModel: SettingsViewModel())
    }
    .theme(DefaultTheme())
}
