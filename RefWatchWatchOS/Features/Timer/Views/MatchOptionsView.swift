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

          // Reset match option
          ActionButton(
            title: "Reset match",
            icon: "trash",
            color: self.theme.colors.accentMuted)
          {
            self.showingResetConfirmation = true
          }

          // Abandon match option
          ActionButton(
            title: "Abandon match",
            icon: "xmark.circle",
            color: self.theme.colors.matchCritical)
          {
            self.showingAbandonConfirmation = true
          }
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
