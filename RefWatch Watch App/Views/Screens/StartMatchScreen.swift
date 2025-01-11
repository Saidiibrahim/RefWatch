//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Displays two options: "From Library" and "Create".
//

import SwiftUI

struct StartMatchScreen: View {
    let matchViewModel: MatchViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Start a New Match")
                .font(.headline)
                .padding()
            
            // Select from library
            NavigationLink(destination: SavedMatchesView(matchViewModel: matchViewModel)) {
                CustomButton(title: "Select Match")
            }
            .padding(.bottom, 10)
            
            // Create new match
            NavigationLink(destination: CreateMatchView(matchViewModel: matchViewModel)) {
                CustomButton(title: "Create Match")
            }
        }
        .navigationTitle("Start Match")
    }
}

// View for creating a new match with settings
struct CreateMatchView: View {
    @Bindable var matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Match settings
                Group {
                    Picker("Duration", selection: $matchViewModel.matchDuration) {
                        ForEach([45, 60, 90], id: \.self) { duration in
                            Text("\(duration) min").tag(duration)
                        }
                    }
                    
                    Picker("Periods", selection: $matchViewModel.numberOfPeriods) {
                        ForEach(1...4, id: \.self) { periods in
                            Text("\(periods)").tag(periods)
                        }
                    }
                    
                    Picker("Half-time", selection: $matchViewModel.halfTimeLength) {
                        ForEach([10, 15, 20], id: \.self) { length in
                            Text("\(length) min").tag(length)
                        }
                    }
                    
                    Toggle("Extra Time", isOn: $matchViewModel.hasExtraTime)
                    Toggle("Penalties", isOn: $matchViewModel.hasPenalties)
                }
                
                // Start match button
                NavigationLink(destination: MatchSetupView(matchViewModel: matchViewModel)) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    matchViewModel.configureMatch(
                        duration: matchViewModel.matchDuration,
                        periods: matchViewModel.numberOfPeriods,
                        halfTimeLength: matchViewModel.halfTimeLength,
                        hasExtraTime: matchViewModel.hasExtraTime,
                        hasPenalties: matchViewModel.hasPenalties
                    )
                })
            }
            .padding()
        }
        .navigationTitle("Match Settings")
    }
}

// View for selecting from saved matches
struct SavedMatchesView: View {
    let matchViewModel: MatchViewModel
    
    var body: some View {
        List {
            NavigationLink(destination: MatchSetupView(matchViewModel: matchViewModel)) {
                VStack(alignment: .leading) {
                    Text("Sample Match")
                        .font(.headline)
                    Text("HOM vs AWA")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Saved Matches")
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel())
    }
}
