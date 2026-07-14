//
//  SignUpView.swift
//  RefWatchiOS
//
//  Clerk AuthView owns sign-up verification, recovery, and MFA steps.
//

import ClerkKitUI
import SwiftUI

struct SignUpView: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator

  var body: some View {
    NavigationStack {
      AuthView()
        .navigationTitle("Create Account")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { self.coordinator.dismiss() }
          }
        }
    }
  }
}
