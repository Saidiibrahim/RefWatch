//
//  ContentView.swift
//  RefereeAssistant
//
//  Description: The Welcome page with two main options: "Start Match" and "Settings".
//

import SwiftUI

struct ContentView: View {
    @State private var matchViewModel = MatchViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Referee Assistant")
                    .font(.headline)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Navigate to the StartMatchScreen with matchViewModel
                    NavigationLinkButton(
                        title: "Start Match",
                        icon: "play.circle.fill",
                        destination: StartMatchScreen(matchViewModel: matchViewModel),
                        backgroundColor: .green
                    )
                    
                    // Navigate to the SettingsScreen with settingsViewModel
                    NavigationLinkButton(
                        title: "Settings",
                        icon: "gear",
                        destination: SettingsScreen(settingsViewModel: settingsViewModel),
                        backgroundColor: .gray
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Referee")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
