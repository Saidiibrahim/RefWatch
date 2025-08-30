//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Displays two options: "From Library" and "Create".
//

import SwiftUI

struct StartMatchScreen: View {
    let matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Start a New Match")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 16) {
                // Select from library
                NavigationLink(destination: SavedMatchesView(
                    matchViewModel: matchViewModel,
                    lifecycle: lifecycle
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Select Match")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.blue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    // Reset match state before selecting a match
                    matchViewModel.resetMatch()
                })
                
                // Create new match
                NavigationLink(destination: CreateMatchView(
                    matchViewModel: matchViewModel,
                    lifecycle: lifecycle
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("Create Match")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.green)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    // Reset match state before creating a new match
                    matchViewModel.resetMatch()
                })
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("Start Match")
        // When the lifecycle leaves idle, close this screen to reveal root routing
        .onChange(of: lifecycle.state) { newValue in
            if newValue != .idle {
                dismiss()
            }
        }
    }
}

// View for creating a new match with settings
struct CreateMatchView: View {
    @Bindable var matchViewModel: MatchViewModel
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    
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
            
            // Start match button - jump into lifecycle kickoff state
            HStack {
                Spacer()
                IconButton(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    size: 50
                ) {
                    // Configure new match from current settings
                    matchViewModel.configureMatch(
                        duration: matchViewModel.matchDuration,
                        periods: matchViewModel.numberOfPeriods,
                        halfTimeLength: matchViewModel.halfTimeLength,
                        hasExtraTime: matchViewModel.hasExtraTime,
                        hasPenalties: matchViewModel.hasPenalties
                    )
                    // Enter kickoff-first state; ContentView will swap screen
                    lifecycle.goToKickoffFirst()
                    // Pop CreateMatchView; StartMatchScreen will auto-dismiss via onChange
                    dismiss()
                }
                .accessibilityIdentifier("startMatchButton")
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
    let lifecycle: MatchLifecycleCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(matchViewModel.savedMatches) { match in
                Button {
                    matchViewModel.selectMatch(match)
                    lifecycle.goToSetup()
                    // Pop SavedMatchesView; StartMatchScreen will auto-dismiss via onChange
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(match.homeTeam) vs \(match.awayTeam)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Duration: \(Int(match.duration/60)) min • Periods: \(match.numberOfPeriods)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Saved Matches")
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen(matchViewModel: MatchViewModel(), lifecycle: MatchLifecycleCoordinator())
    }
}
