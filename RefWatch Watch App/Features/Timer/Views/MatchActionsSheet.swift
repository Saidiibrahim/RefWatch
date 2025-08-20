//
//  MatchActionsSheet.swift
//  RefWatch Watch App
//
//  Description: Sheet presented when user long-presses on TimerView, showing match action options
//

import SwiftUI

/// Sheet view presenting three action options for referees during a match
struct MatchActionsSheet: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State for controlling navigation destinations
    @State private var showingMatchLogs = false
    @State private var showingOptions = false
    @State private var showingEndHalfConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Match Actions")
                .font(.headline)
                .padding(.top)
            
            // Action buttons in vertical layout for watch
            VStack(spacing: 16) {
                // Match Log Button
                Button(action: {
                    showingMatchLogs = true
                }) {
                    ActionButtonView(
                        icon: "list.bullet",
                        label: "Match Log",
                        color: .blue
                    )
                }
                
                // Options Button
                Button(action: {
                    showingOptions = true
                }) {
                    ActionButtonView(
                        icon: "ellipsis.circle",
                        label: "Options",
                        color: .gray
                    )
                }
                
                // End Half Button (conditional based on match state)
                if matchViewModel.isHalfTime {
                    // During half-time: Show "End Half-Time" option
                    Button(action: {
                        matchViewModel.endHalfTimeManually()
                        dismiss()
                    }) {
                        ActionButtonView(
                            icon: "forward.fill",
                            label: "End Half-Time",
                            color: .orange
                        )
                    }
                } else {
                    // During match: Show "End Half" option
                    Button(action: {
                        showingEndHalfConfirmation = true
                    }) {
                        ActionButtonView(
                            icon: "checkmark.circle",
                            label: "End Half",
                            color: .green
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingMatchLogs) {
            MatchLogsView(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showingOptions) {
            MatchOptionsView(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showingEndHalfConfirmation) {
            EndHalfConfirmationView(
                matchViewModel: matchViewModel,
                parentDismiss: { dismiss() }
            )
        }
    }
}

/// Individual action button component
private struct ActionButtonView: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Label
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

#Preview {
    MatchActionsSheet(matchViewModel: MatchViewModel())
}