//
//  ContentView.swift
//  RefereeAssistant
//
//  Description: The Welcome page with two main options: "Start Match" and "Settings".
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to Referee Assistant")
                    .font(.headline)
                    .padding()
                
                // Navigate to the StartMatchScreen
                NavigationLink(destination: StartMatchScreen()) {
                    CustomButton(title: "Start Match")
                }
                .padding(.bottom, 10)
                
                // Navigate to the SettingsScreen
                NavigationLink(destination: SettingsScreen()) {
                    CustomButton(title: "Settings")
                }
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
