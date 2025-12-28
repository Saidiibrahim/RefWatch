//
//  MatchOptionsView.swift
//  RefWatchWatchOS
//
//  Description: Options menu for match management actions during gameplay
//

import SwiftUI
import RefWatchCore

/// Options menu providing various match management actions
struct MatchOptionsView: View {
    let matchViewModel: MatchViewModel
    var lifecycle: MatchLifecycleCoordinator? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    // State for controlling alert presentations
    @State private var showingResetConfirmation = false
    @State private var showingAbandonConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Options") {
                    // Home option
                    ActionButton(
                        title: "Home",
                        icon: "house",
                        color: theme.colors.matchPositive
                    ) {
                        matchViewModel.navigateHome()
                        lifecycle?.resetToStart()
                        dismiss()
                    }
                    //.listRowBackground(Color.clear) // Remove list row background

                    // MARK: - Kit Colours Feature (On Hold)
                    // The custom kit colours feature is currently on hold and not exposed to users.
                    // This feature will be re-enabled once the beta supports custom kit colour configuration.
                    // Keeping the code commented out for future reference and easy re-enablement.
                    /*
                    ThemeCardContainer(role: .secondary, minHeight: 72) {
                        HStack(alignment: .top, spacing: theme.spacing.m) {
                            Image(systemName: "paintpalette")
                                .font(.title2)
                                .foregroundStyle(theme.colors.accentSecondary)

                            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                Text("Kit colours coming soon")
                                    .font(theme.typography.cardHeadline)
                                    .foregroundStyle(theme.colors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)

                                Text("Set custom kit colours once the beta supports them.")
                                    .font(theme.typography.cardMeta)
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    //.listRowBackground(Color.clear) // Remove list row background
                    */

                    // Reset match option
                    ActionButton(
                        title: "Reset match",
                        icon: "trash",
                        color: theme.colors.accentMuted
                    ) {
                        showingResetConfirmation = true
                    }
                    //.listRowBackground(Color.clear) // Remove list row background

                    // Abandon match option
                    ActionButton(
                        title: "Abandon match",
                        icon: "xmark.circle",
                        color: theme.colors.matchCritical
                    ) {
                        showingAbandonConfirmation = true
                    }
                    //.listRowBackground(Color.clear) // Remove list row background
                }
            }
            .listStyle(.carousel)
            .scrollContentBackground(.hidden)
            .background(theme.colors.backgroundPrimary)
        }
        .tint(theme.colors.accentSecondary)
        .alert("Reset Match", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                matchViewModel.resetMatch()
                lifecycle?.resetToStart()
                dismiss()
            }
        } message: {
            Text("This will reset all match data including score, cards, and events. This action cannot be undone.")
        }
        .alert("Abandon Match", isPresented: $showingAbandonConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Abandon", role: .destructive) {
                matchViewModel.abandonMatch()
                dismiss()
            }
        } message: {
            Text("This will end the match immediately and record it as abandoned. This action cannot be undone.")
        }
    }
}


#Preview {
    MatchOptionsView(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
