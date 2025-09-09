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
    
    // State for controlling alert presentations
    @State private var showingResetConfirmation = false
    @State private var showingAbandonConfirmation = false
    @State private var showingColorPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Options list - using system dismiss (X button) per WatchOS best practices
                    VStack(spacing: 12) {
                        // Home option
                        ActionButton(
                            title: "Home",
                            icon: "house",
                            color: .green
                        ) {
                            matchViewModel.navigateHome()
                            lifecycle?.resetToStart()
                            dismiss()
                        }
                        
                        // Choose colours option (placeholder for future feature)
                        ActionButton(
                            title: "Choose colours",
                            icon: "paintpalette",
                            color: .orange
                        ) {
                            showingColorPicker = true
                        }
                        
                        // Reset match option
                        ActionButton(
                            title: "Reset match",
                            icon: "trash",
                            color: .blue
                        ) {
                            showingResetConfirmation = true
                        }
                        
                        // Abandon match option
                        ActionButton(
                            title: "Abandon match",
                            icon: "xmark.circle",
                            color: .red
                        ) {
                            showingAbandonConfirmation = true
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Options")
        }
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
        .alert("Choose Colours", isPresented: $showingColorPicker) {
            Button("OK") { }
        } message: {
            Text("Team color customization will be available in a future update.")
        }
    }
}


#Preview {
    MatchOptionsView(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
