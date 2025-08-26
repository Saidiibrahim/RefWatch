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
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Simplified confirmation question
            Text("Are you sure you want to 'End Half'?")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
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
                    matchViewModel.endCurrentPeriod()
                    dismiss()
                    parentDismiss()
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