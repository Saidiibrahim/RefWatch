//
//  SettingsAuthViewModel.swift
//  RefZoneiOS
//
//  Handles email/password and third-party sign-in flows from the Settings tab.
//

import Combine
import Foundation
import OSLog

@MainActor
final class SettingsAuthViewModel: ObservableObject {
  @Published var email: String = ""
  @Published var password: String = ""
  @Published var isPerformingAction: Bool = false
  @Published var alertMessage: String?

  private let auth: SupabaseAuthController
  private var cancellables = Set<AnyCancellable>()

  init(auth: SupabaseAuthController) {
    self.auth = auth

    auth.$lastError
      .receive(on: RunLoop.main)
      .sink { [weak self] error in
        guard let self else { return }
        self.alertMessage = error?.errorDescription
      }
      .store(in: &cancellables)
  }

  func signIn() async {
    await runAuthTask {
      let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
      try await auth.signIn(email: trimmedEmail, password: password)
    }
  }

  func signUp() async {
    await runAuthTask {
      let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
      try await auth.signUp(email: trimmedEmail, password: password)
    }
  }

  func signInWithApple() async {
    await runAuthTask {
      try await auth.signInWithApple()
    }
  }

  func signInWithGoogle() async {
    await runAuthTask {
      try await auth.signInWithGoogle()
    }
  }

  func signOut() async {
    await runAuthTask {
      try await auth.signOut()
    }
  }

  private func resetForm() {
    email = ""
    password = ""
  }

  private func runAuthTask(_ action: () async throws -> Void) async {
    guard isPerformingAction == false else { return }
    isPerformingAction = true
    defer { isPerformingAction = false }

    do {
      try await action()
      resetForm()
      alertMessage = nil
    } catch {
      let mapped = SupabaseAuthError.map(error)
      AppLog.supabase.error("Auth flow failed: \(error.localizedDescription, privacy: .public)")
      alertMessage = mapped.errorDescription
    }
  }
}
