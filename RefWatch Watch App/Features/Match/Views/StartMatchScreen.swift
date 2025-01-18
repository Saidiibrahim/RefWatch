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
            NavigationLink(destination: MatchSetupView(matchViewModel: matchViewModel)) {
                CustomButton(title: "Create Match")
            }
        }
        .navigationTitle("Start Match")
    }
}

// View for creating a new match with settings
struct CreateMatchView: View {
    @Bindable var matchViewModel: MatchViewModel
    
    var body: some View {
        List {
            // Duration
            NavigationLink(destination: SettingPickerView(
                title: "Duration",
                values: [40, 45, 50],
                selection: $matchViewModel.matchDuration,
                formatter: { "\($0) min" }
            )) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text("\(matchViewModel.matchDuration) min")
                        .foregroundColor(.gray)
                }
            }
            
            // Periods
            NavigationLink(destination: SettingPickerView(
                title: "Periods",
                values: [1, 2, 3, 4],
                selection: $matchViewModel.numberOfPeriods,
                formatter: String.init
            )) {
                HStack {
                    Text("Periods")
                    Spacer()
                    Text("\(matchViewModel.numberOfPeriods)")
                        .foregroundColor(.gray)
                }
            }
            
            // Half-time length
            NavigationLink(destination: SettingPickerView(
                title: "Half-time",
                values: [10, 15, 20],
                selection: $matchViewModel.halfTimeLength,
                formatter: { "\($0) min" }
            )) {
                HStack {
                    Text("HT Length")
                    Spacer()
                    Text("\(matchViewModel.halfTimeLength) min")
                        .foregroundColor(.gray)
                }
            }
            
            // Toggles
            Toggle("Extra Time", isOn: $matchViewModel.hasExtraTime)
            Toggle("Penalties", isOn: $matchViewModel.hasPenalties)
            
            // Start match button
            NavigationLink(destination: MatchKickOffView(matchViewModel: matchViewModel)) {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Spacer()
                }
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
