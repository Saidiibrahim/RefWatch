//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Displays two options: "From Library" and "Create".
//

import SwiftUI

struct StartMatchScreen: View {
    let matchViewModel: MatchViewModel
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
                    onExitToRoot: { 
                        // Dismiss multiple views to get back to StartMatchScreen
                        dismiss()
                    }
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
                    onExitToRoot: { 
                        // Dismiss CreateMatchView to get back to StartMatchScreen
                        dismiss()
                    }
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
    }
}

// View for creating a new match with settings
struct CreateMatchView: View {
    @Bindable var matchViewModel: MatchViewModel
    let onExitToRoot: () -> Void
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
            
            // Start match button - using the icon button style
            HStack {
                Spacer()
                NavigationIconButton(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    size: 50,
                    destination: MatchKickOffView(
                        matchViewModel: matchViewModel,
                        onExitToRoot: {
                            // Pop CreateMatchView to reveal StartMatchScreen
                            dismiss()
                        }
                    )
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
    let onExitToRoot: () -> Void
    
    var body: some View {
        List {
            NavigationLink(destination: MatchSetupView(matchViewModel: matchViewModel, onExitToRoot: onExitToRoot)) {
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
