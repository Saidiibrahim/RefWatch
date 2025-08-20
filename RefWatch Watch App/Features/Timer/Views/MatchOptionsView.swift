//
//  MatchOptionsView.swift
//  RefWatch Watch App
//
//  Description: Options menu for match management actions during gameplay
//

import SwiftUI

/// Options menu providing various match management actions
struct MatchOptionsView: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State for controlling alert presentations
    @State private var showingResetConfirmation = false
    @State private var showingAbandonConfirmation = false
    @State private var showingColorPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Options list
                VStack(spacing: 12) {
                    // Home option
                    OptionRowView(
                        icon: "house",
                        title: "Home",
                        color: .green
                    ) {
                        matchViewModel.navigateHome()
                        dismiss()
                    }
                    
                    // Choose colours option (placeholder for future feature)
                    OptionRowView(
                        icon: "paintpalette",
                        title: "Choose colours",
                        color: .orange
                    ) {
                        showingColorPicker = true
                    }
                    
                    // Reset match option
                    OptionRowView(
                        icon: "trash",
                        title: "Reset match",
                        color: .blue
                    ) {
                        showingResetConfirmation = true
                    }
                    
                    // Abandon match option
                    OptionRowView(
                        icon: "xmark.circle",
                        title: "Abandon match",
                        color: .red
                    ) {
                        showingAbandonConfirmation = true
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .alert("Reset Match", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                matchViewModel.resetMatch()
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

/// Individual option row component
private struct OptionRowView: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Icon circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    MatchOptionsView(matchViewModel: MatchViewModel())
}