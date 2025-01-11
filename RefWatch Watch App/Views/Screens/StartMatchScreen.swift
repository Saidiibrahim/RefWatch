//
//  StartMatchScreen.swift
//  RefereeAssistant
//
//  Description: Displays two options: "From Library" and "Create".
//

import SwiftUI

struct StartMatchScreen: View {
    
    var body: some View {
        VStack {
            Text("Start a New Match")
                .font(.headline)
                .padding()
            
            // "From Library" - Currently just shows "Coming up"
            NavigationLink(destination: ComingUpView()) {
                CustomButton(title: "From Library")
            }
            .padding(.bottom, 10)
            
            // "Create" - Navigates to a form or direct create match page
            NavigationLink(destination: CreateMatchView()) {
                CustomButton(title: "Create")
            }
        }
        .navigationTitle("Start Match")
    }
}

// A simple view that displays "Coming up"
struct ComingUpView: View {
    var body: some View {
        Text("Coming up...")
            .font(.headline)
    }
}

// A simple view that has a button to actually start the match
struct CreateMatchView: View {
    @ObservedObject var matchViewModel = MatchViewModel()
    
    var body: some View {
        VStack {
            Text("Create Your Match")
                .font(.headline)
                .padding()
            
            // Button that starts the match (starts the timer)
            Button(action: {
                matchViewModel.startMatch()
            }) {
                CustomButton(title: "Start Match")
            }
            
            // Display the timer, if running, or initial state
            Text(matchViewModel.formattedElapsedTime)
                .font(.title2)
                .padding()
        }
        .navigationTitle("New Match")
    }
}

struct StartMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        StartMatchScreen()
    }
}
