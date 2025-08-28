//
//  FullTimeView.swift
//  RefWatch Watch App
//
//  Description: Full-time display showing final scores and option to end match
//

import SwiftUI

struct FullTimeView: View {
    let matchViewModel: MatchViewModel
    let onReturnHome: () -> Void
    @State private var showingEndMatchConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Time indicator
            VStack(spacing: 4) {
                Text(formattedCurrentTime)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text("Full Time")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Team score boxes
            HStack(spacing: 16) {
                TeamScoreBox(
                    teamName: "HOM",
                    score: matchViewModel.currentMatch?.homeScore ?? 0
                )
                
                TeamScoreBox(
                    teamName: "AWA",
                    score: matchViewModel.currentMatch?.awayScore ?? 0
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // End Match Button
            Button(action: {
                showingEndMatchConfirmation = true
            }) {
                Text("End Match")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.green)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 45)
        }
        .background(Color.black)
        .sheet(isPresented: $showingEndMatchConfirmation) {
            EndMatchConfirmationView(
                matchViewModel: matchViewModel,
                onReturnHome: onReturnHome
            )
        }
    }
    
    // Computed property for current time
    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: Date())
    }
}

// Team score box component
private struct TeamScoreBox: View {
    let teamName: String
    let score: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(teamName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text("\(score)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.7))
        )
    }
}

#Preview {
    let viewModel = MatchViewModel()
    // Set up match with some scores for preview
    viewModel.configureMatch(duration: 90, periods: 2, halfTimeLength: 15, hasExtraTime: false, hasPenalties: false)
    viewModel.updateScore(isHome: true, increment: true)
    viewModel.updateScore(isHome: false, increment: true)
    viewModel.isFullTime = true
    
    return FullTimeView(matchViewModel: viewModel, onReturnHome: { })
}