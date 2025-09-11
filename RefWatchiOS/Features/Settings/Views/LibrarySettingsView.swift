//
//  LibrarySettingsView.swift
//  RefWatchiOS
//

import SwiftUI

struct LibrarySettingsView: View {
    var body: some View {
        List {
            Section("Collections") {
                NavigationLink { Text("Teams (placeholder)").navigationTitle("Teams") } label: {
                    Label("Teams", systemImage: "person.3")
                }
                NavigationLink { Text("Competitions (placeholder)").navigationTitle("Competitions") } label: {
                    Label("Competitions", systemImage: "trophy")
                }
                NavigationLink { Text("Venues (placeholder)").navigationTitle("Venues") } label: {
                    Label("Venues", systemImage: "building.2")
                }
            }
        }
        .navigationTitle("Library")
    }
}

#Preview { NavigationStack { LibrarySettingsView() } }

