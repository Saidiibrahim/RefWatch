//
//  SignedOutFeaturePlaceholder.swift
//  RefWatchiOS
//
//  Shared placeholder informing users that a feature requires authentication.
//

import SwiftUI

struct SignedOutFeaturePlaceholder: View {
  @EnvironmentObject private var coordinator: AuthenticationCoordinator

  let description: String

  var body: some View {
    VStack(spacing: 16) {
      ContentUnavailableView(
        "Sign in required",
        systemImage: "person.crop.circle.badge.exclamationmark",
        description: Text(self.description))
        .padding(.horizontal)

      Button {
        self.coordinator.showSignIn()
      } label: {
        Label("Sign In", systemImage: "person.crop.circle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 32)

      Button {
        self.coordinator.showSignUp()
      } label: {
        Label("Create Account", systemImage: "sparkles")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .padding(.horizontal, 32)
    }
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground).opacity(0.001))
  }
}

#if DEBUG
#Preview {
  SignedOutFeaturePlaceholder(
    description: "Sign in to manage matches on your iPhone.")
    .environmentObject(
      AuthenticationCoordinator(
        authController: SupabaseAuthController(clientProvider: SupabaseClientProvider.shared)))
}
#endif
