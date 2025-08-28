//
//  EndMatchConfirmationView.swift
//  RefWatch Watch App
//
//  Description: Confirmation dialog for ending the match
//

import SwiftUI

/// Confirmation view for ending the match and returning to home screen
struct EndMatchConfirmationView: View {
    let matchViewModel: MatchViewModel
    let onReturnHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Confirmation question
            Text("Are you sure you want to 'End Match'?")
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
                    // Dismiss confirmation sheet
                    dismiss()
                    // Finalize match immediately to freeze state and avoid intermediate UI
                    matchViewModel.finalizeMatch()
                    // Unwind navigation back to StartMatchScreen
                    onReturnHome()
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
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.isFullTime = true
    
    return EndMatchConfirmationView(
        matchViewModel: viewModel,
        onReturnHome: { }
    )
}