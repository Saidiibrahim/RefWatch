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
        VStack(spacing: 20) {
            Text("Start a New Match")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 16) {
                // Select from library
                NavigationLinkButton(
                    title: "Select Match",
                    icon: "folder",
                    destination: SavedMatchesView(matchViewModel: matchViewModel),
                    backgroundColor: .blue
                )
                
                // Create new match
                NavigationLinkButton(
                    title: "Create Match",
                    icon: "plus.circle.fill",
                    destination: CreateMatchView(matchViewModel: matchViewModel),
                    backgroundColor: .green
                )
            }
            .padding(.horizontal)
            
            Spacer()
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
            NavigationLinkRow(
                title: "Duration",
                value: "\(matchViewModel.matchDuration) min",
                destination: SettingPickerView(
                    title: "Duration",
                    values: [40, 45, 50],
                    selection: $matchViewModel.matchDuration,
                    formatter: { "\($0) min" }
                )
            )
            
            // Periods
            NavigationLinkRow(
                title: "Periods",
                value: "\(matchViewModel.numberOfPeriods)",
                destination: SettingPickerView(
                    title: "Periods",
                    values: [1, 2, 3, 4],
                    selection: $matchViewModel.numberOfPeriods,
                    formatter: String.init
                )
            )
            
            // Half-time length
            NavigationLinkRow(
                title: "HT Length",
                value: "\(matchViewModel.halfTimeLength) min",
                destination: SettingPickerView(
                    title: "Half-time",
                    values: [10, 15, 20],
                    selection: $matchViewModel.halfTimeLength,
                    formatter: { "\($0) min" }
                )
            )
            
            // Toggles
            Toggle("Extra Time", isOn: $matchViewModel.hasExtraTime)
            Toggle("Penalties", isOn: $matchViewModel.hasPenalties)
            
            // Start match button - using the icon button style
            HStack {
                Spacer()
                NavigationIconButton(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    size: 50,
                    destination: MatchKickOffView(matchViewModel: matchViewModel)
                )
                Spacer()
            }
            .listRowBackground(Color.clear) // Remove grey background from List item
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sample Match")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("HOM vs AWA")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle()) // Remove grey background
        }
        .navigationTitle("Saved Matches")
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel())
    }
}
