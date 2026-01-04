//
//  MatchOptionsView.swift
//  RefWatchWatchOS
//
//  Description: Options menu for match management actions during gameplay
//

import RefWatchCore
import SwiftUI

/// Options menu providing various match management actions
struct MatchOptionsView: View {
  let matchViewModel: MatchViewModel
  var lifecycle: MatchLifecycleCoordinator?
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
            color: self.theme.colors.matchPositive)
          {
            self.matchViewModel.navigateHome()
            self.lifecycle?.resetToStart()
            self.dismiss()
          }
          // .listRowBackground(Color.clear) // Remove list row background

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
            color: self.theme.colors.accentMuted)
          {
            self.showingResetConfirmation = true
          }
          // .listRowBackground(Color.clear) // Remove list row background

          // Abandon match option
          ActionButton(
            title: "Abandon match",
            icon: "xmark.circle",
            color: self.theme.colors.matchCritical)
          {
            self.showingAbandonConfirmation = true
          }
          // .listRowBackground(Color.clear) // Remove list row background
        }
      }
      .listStyle(.carousel)
      .scrollContentBackground(.hidden)
      .background(self.theme.colors.backgroundPrimary)
    }
    .tint(self.theme.colors.accentSecondary)
    .alert("Reset Match", isPresented: self.$showingResetConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) {
        self.matchViewModel.resetMatch()
        self.lifecycle?.resetToStart()
        self.dismiss()
      }
    } message: {
      Text("This will reset all match data including score, cards, and events. This action cannot be undone.")
    }
    .alert("Abandon Match", isPresented: self.$showingAbandonConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Abandon", role: .destructive) {
        self.matchViewModel.abandonMatch()
        self.dismiss()
      }
    } message: {
      Text("This will end the match immediately and record it as abandoned. This action cannot be undone.")
    }
  }
}

#Preview {
  MatchOptionsView(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
