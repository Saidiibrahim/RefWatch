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
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            ForEach(settingsViewModel.misconductTemplates) { template in
                Button {
                    handleSelection(template)
                } label: {
                    MisconductTemplateRow(
                        template: template,
                        isSelected: template.id == selectedTemplateID
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(rowInsets)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.carousel)
        .scrollContentBackground(.hidden)
        .padding(.vertical, theme.components.listRowVerticalInset)
        .background(theme.colors.backgroundPrimary)
        .navigationTitle("Misconduct Template")
        .animation(.easeInOut(duration: 0.2), value: selectedTemplateID)
    }

    private var selectedTemplateID: String {
        settingsViewModel.settings.selectedMisconductTemplateID
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(
            top: theme.components.listRowVerticalInset,
            leading: 0,
            bottom: theme.components.listRowVerticalInset,
            trailing: 0
        )
    }

    private func handleSelection(_ template: MisconductTemplate) {
        settingsViewModel.updateMisconductTemplate(id: template.id)
        dismiss()
    }
}

private struct MisconductTemplateRow: View {
    @Environment(\.theme) private var theme

    let template: MisconductTemplate
    let isSelected: Bool

    var body: some View {
        ThemeCardContainer(role: .secondary, minHeight: theme.components.buttonHeight) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
                    Text(template.name)
                        .font(theme.typography.cardHeadline)
                        .foregroundStyle(theme.colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        selectionBadge
                    }
                }

                Text(template.region)
                    .font(theme.typography.cardMeta)
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let notes = template.notes, notes.isEmpty == false {
                    Text(notes)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .overlay(selectionOutline)
    }

    private var selectionOutline: some View {
        RoundedRectangle(cornerRadius: theme.components.cardCornerRadius, style: .continuous)
            .stroke(theme.colors.matchPositive, lineWidth: isSelected ? 2 : 0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var selectionBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(theme.typography.iconAccent)
            .foregroundStyle(theme.colors.matchPositive)
            .padding(.horizontal, theme.spacing.xs)
            .padding(.vertical, theme.spacing.xs / 2)
            .background(
                Capsule()
                    .fill(theme.colors.matchPositive.opacity(0.2))
            )
    }
}

#Preview {
    NavigationStack {
        MisconductTemplateSelectionView(settingsViewModel: SettingsViewModel())
    }
    .theme(DefaultTheme())
}
