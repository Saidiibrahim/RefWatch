//
//  SignInView.swift
//  RefWatchiOS
//
//  Clerk-hosted native authentication surface.
//

import ClerkKitUI
import SwiftUI

struct SignInView: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator

  var body: some View {
    NavigationStack {
      AuthView()
        .navigationTitle("Sign In")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { self.coordinator.dismiss() }
          }
        }
    }
  }
}
