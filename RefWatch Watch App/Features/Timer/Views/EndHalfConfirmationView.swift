//
//  EndHalfConfirmationView.swift
//  RefWatch Watch App
//
//  Description: Confirmation dialog for ending the current half/period
//

import SwiftUI

/// Confirmation view for ending the current match period
struct EndHalfConfirmationView: View {
    let matchViewModel: MatchViewModel
    let parentDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("End Period")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.top)
            
            // Current period info
            VStack(spacing: 8) {
                Text(periodDisplayName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Current Time: \(matchViewModel.matchTime)")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
                
                if matchViewModel.isInStoppage {
                    Text("Stoppage Time: +\(matchViewModel.formattedStoppageTime)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
            
            // Confirmation message
            Text(confirmationMessage)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                // Confirm button
                Button(action: {
                    matchViewModel.endCurrentPeriod()
                    dismiss()
                    parentDismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("End \(periodDisplayName)")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red)
                    )
                }
                .buttonStyle(.plain)
                
                // Cancel button
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
    }
    
    /// Display name for the current period
    private var periodDisplayName: String {
        switch matchViewModel.currentPeriod {
        case 1: return "First Half"
        case 2: return "Second Half"
        case 3: return "Extra Time 1"
        case 4: return "Extra Time 2"
        default: return "Period \(matchViewModel.currentPeriod)"
        }
    }
    
    /// Confirmation message based on current period
    private var confirmationMessage: String {
        switch matchViewModel.currentPeriod {
        case 1:
            return "This will end the first half and start half-time."
        case 2:
            if matchViewModel.currentMatch?.hasExtraTime == true {
                return "This will end the second half. Extra time will begin if needed."
            } else {
                return "This will end the second half and the match."
            }
        default:
            return "This will end the current period."
        }
    }
}

#Preview {
    let viewModel = MatchViewModel()
    viewModel.startMatch()
    
    return EndHalfConfirmationView(
        matchViewModel: viewModel,
        parentDismiss: { }
    )
}