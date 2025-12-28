//
//  SettingsAuthViewModel.swift
//  RefWatchiOS
//
//  Handles account management interactions surfaced from the Settings tab.
//

import Combine
import Foundation
import OSLog

@MainActor
final class SettingsAuthViewModel: ObservableObject {
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

  func signOut() async {
    await runAuthTask {
      try await auth.signOut()
    }
  }

  private func runAuthTask(_ action: () async throws -> Void) async {
    guard isPerformingAction == false else { return }
    isPerformingAction = true
    defer { isPerformingAction = false }

    do {
      try await action()
      alertMessage = nil
    } catch {
      let mapped = SupabaseAuthError.map(error)
      AppLog.supabase.error("Account action failed: \(error.localizedDescription, privacy: .public)")
      alertMessage = mapped.errorDescription
    }
  }
}
