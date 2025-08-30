//
//  EndHalfConfirmationView.swift
//  RefWatch Watch App
//
//  Description: Simple confirmation dialog for ending the current half/period
//

import SwiftUI

/// Simplified confirmation view for ending the current match period
struct EndHalfConfirmationView: View {
    let matchViewModel: MatchViewModel
    let parentDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Check if we're ending the second half of a regular match
    private var isEndingSecondHalf: Bool {
        guard let match = matchViewModel.currentMatch else { return false }
        return matchViewModel.currentPeriod == 2 && match.numberOfPeriods == 2
    }
    
    private var confirmationText: String {
        isEndingSecondHalf ? "Are you sure you want to 'End Match'?" : "Are you sure you want to 'End Half'?"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Dynamic confirmation question
            Text(confirmationText)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.9)
                .padding(.horizontal)
            
            Spacer()
            
            // Yes/No buttons in horizontal layout
            HStack(spacing: 16) {
                // No button
                Button(action: {
                    dismiss()
                }) {
                    Text("No")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.gray.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                
                // Yes button
                Button(action: {
                    if isEndingSecondHalf {
                        // End the second half - this will trigger full-time display
                        matchViewModel.endCurrentPeriod()
                        dismiss()
                        parentDismiss()
                    } else {
                        // End the first half - transition to half-time
                        matchViewModel.endCurrentPeriod()
                        matchViewModel.isHalfTime = true
                        dismiss()
                        parentDismiss()
                    }
                }) {
                    Text("Yes")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.black)
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