// SubstitutionFlow.swift
// Description: View for handling player substitution process

import RefWatchCore
import SwiftUI

struct SubstitutionFlow: View {
  let team: TeamDetailsView.TeamType
  let matchViewModel: MatchViewModel
  let setupViewModel: MatchSetupViewModel

  @State private var step: SubstitutionStep
  @State private var playerOffNumber: Int?
  @State private var playerOnNumber: Int?
  @Environment(\.dismiss) private var dismiss
  @Environment(SettingsViewModel.self) private var settingsViewModel

  enum SubstitutionStep {
    case playerOff
    case playerOn
    case confirmation
  }

  // Initialize with proper starting step based on settings
  init(
    team: TeamDetailsView.TeamType,
    matchViewModel: MatchViewModel,
    setupViewModel: MatchSetupViewModel,
    initialStep: SubstitutionStep = .playerOff)
  {
    self.team = team
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel
    self._step = State(initialValue: initialStep)
  }

  var body: some View {
    Group {
      switch self.step {
      case .playerOff:
        PlayerNumberInputView(
          team: self.team,
          goalType: nil,
          cardType: nil,
          context: "player off",
          onComplete: { number in
            self.playerOffNumber = number
            self.advanceAfterCapturingPlayerOff()
          })

      case .playerOn:
        PlayerNumberInputView(
          team: self.team,
          goalType: nil,
          cardType: nil,
          context: "player on",
          onComplete: { number in
            self.playerOnNumber = number
            self.advanceAfterCapturingPlayerOn()
          })
          .navigationBarBackButtonHidden(false)

      case .confirmation:
        self.confirmationView
          // .navigationTitle("Confirm Substitution")
            .navigationBarBackButtonHidden(false)
      }
    }
  }

  private var confirmationView: some View {
    VStack(spacing: 20) {
      // Text("Substitution")
      //     .font(.system(size: 16, weight: .medium))

      VStack(spacing: 12) {
        HStack {
          Text("Player Off:")
            .font(.body)
          Spacer()
          Text("#\(self.playerOffNumber ?? 0)")
            .font(.title2)
            .fontWeight(.medium)
        }

        HStack {
          Text("Player On:")
            .font(.body)
          Spacer()
          Text("#\(self.playerOnNumber ?? 0)")
            .font(.title2)
            .fontWeight(.medium)
        }
      }
      // .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.gray.opacity(0.1)))

      Spacer()

      // Replace with custom button
      Button("Confirm Substitution") {
        self.recordSubstitution()
      }
      // .font(.headline)
      // .padding()
      // .frame(maxWidth: .infinity)
      // .background(Color.blue)
      // .foregroundColor(.white)
      // .cornerRadius(12)
      // .padding(.horizontal)
    }
    .padding()
  }

  private func recordSubstitution() {
    guard let offNumber = playerOffNumber,
          let onNumber = playerOnNumber else { return }

    print("DEBUG: Recording substitution - Off: #\(offNumber), On: #\(onNumber), Team: \(self.team)")

    // Map team to new enum
    let teamSide: TeamSide = self.team == .home ? .home : .away

    // Record substitution using new comprehensive system
    self.matchViewModel.recordSubstitution(
      team: teamSide,
      playerOut: offNumber,
      playerIn: onNumber)

    print("DEBUG: Substitution recorded successfully using new system")

    // Navigate back to middle screen
    self.setupViewModel.setSelectedTab(1)

    // Dismiss the entire flow
    self.dismiss()
  }

  private func advanceAfterCapturingPlayerOff() {
    if self.playerOnNumber == nil {
      self.step = .playerOn
    } else {
      self.transitionToConfirmationOrRecord()
    }
  }

  private func advanceAfterCapturingPlayerOn() {
    if self.playerOffNumber == nil {
      self.step = .playerOff
    } else {
      self.transitionToConfirmationOrRecord()
    }
  }

  private func transitionToConfirmationOrRecord() {
    if self.settingsViewModel.settings.confirmSubstitutions {
      self.step = .confirmation
    } else {
      self.recordSubstitution()
    }
  }
}

// MARK: - Preview Support

#Preview("Making Substitution - Player Off") {
  SubstitutionFlow(
    team: .home,
    matchViewModel: PreviewMatchViewModel(),
    setupViewModel: PreviewMatchSetupViewModel())
    .environment(SettingsViewModel())
}

#Preview("Making Substitution - Player On") {
  SubstitutionFlowWithState(
    team: .away,
    initialStep: .playerOn)
    .environment(SettingsViewModel())
}

#Preview("Confirming Substitution") {
  SubstitutionFlowWithState(
    team: .home,
    initialStep: .confirmation)
    .environment(SettingsViewModel())
}

// MARK: - Preview Helper View

private struct SubstitutionFlowWithState: View {
  let team: TeamDetailsView.TeamType
  let initialStep: SubstitutionFlow.SubstitutionStep

  var body: some View {
    SubstitutionFlowPreview(
      team: self.team,
      matchViewModel: PreviewMatchViewModel(),
      setupViewModel: PreviewMatchSetupViewModel(),
      initialStep: self.initialStep)
  }
}

private struct SubstitutionFlowPreview: View {
  let team: TeamDetailsView.TeamType
  let matchViewModel: MatchViewModel
  let setupViewModel: MatchSetupViewModel
  let initialStep: SubstitutionFlow.SubstitutionStep

  @State private var step: SubstitutionFlow.SubstitutionStep
  @State private var playerOffNumber: Int? = 10
  @State private var playerOnNumber: Int? = 23
  @Environment(\.dismiss) private var dismiss

  init(
    team: TeamDetailsView.TeamType,
    matchViewModel: MatchViewModel,
    setupViewModel: MatchSetupViewModel,
    initialStep: SubstitutionFlow.SubstitutionStep)
  {
    self.team = team
    self.matchViewModel = matchViewModel
    self.setupViewModel = setupViewModel
    self.initialStep = initialStep
    self._step = State(initialValue: initialStep)
  }

  var body: some View {
    NavigationStack {
      switch self.step {
      case .playerOff:
        PlayerNumberInputView(
          team: self.team,
          goalType: nil,
          cardType: nil,
          context: "player off",
          onComplete: { number in
            self.playerOffNumber = number
            self.step = .playerOn
          })

      case .playerOn:
        PlayerNumberInputView(
          team: self.team,
          goalType: nil,
          cardType: nil,
          context: "player on",
          onComplete: { number in
            self.playerOnNumber = number
            self.step = .confirmation
          })
          .navigationBarBackButtonHidden(false)

      case .confirmation:
        self.confirmationView
//                    .navigationTitle("Confirm Substitution")
            .navigationBarBackButtonHidden(false)
      }
    }
  }

  private var confirmationView: some View {
    VStack(spacing: 20) {
//            Text("Substitution")
//                .font(.headline)

      VStack(spacing: 12) {
        HStack {
          Text("Player Off:")
            .font(.body)
          Spacer()
          Text("#\(self.playerOffNumber ?? 10)")
            .font(.title2)
            .fontWeight(.medium)
        }

        HStack {
          Text("Player On:")
            .font(.body)
          Spacer()
          Text("#\(self.playerOnNumber ?? 23)")
            .font(.title2)
            .fontWeight(.medium)
        }
      }
      // .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.gray.opacity(0.1)))

      Spacer()

      Button("Confirm Substitution") {
        self.recordSubstitution()
      }
      // .font(.headline)
      // .padding()
      // .frame(maxWidth: .infinity)
      // .background(Color.blue)
      // .foregroundColor(.white)
      // .cornerRadius(12)
      // .padding(.horizontal)
    }
    // .padding()
  }

  private func recordSubstitution() {
    guard let offNumber = playerOffNumber,
          let onNumber = playerOnNumber else { return }

    print("Preview: Recording substitution - Off: #\(offNumber), On: #\(onNumber), Team: \(self.team)")

    // Map team to new enum
    let teamSide: TeamSide = self.team == .home ? .home : .away

    // Record substitution using mock system
    self.matchViewModel.recordSubstitution(
      team: teamSide,
      playerOut: offNumber,
      playerIn: onNumber)

    print("Preview: Substitution recorded successfully")

    // Navigate back to middle screen
    self.setupViewModel.setSelectedTab(1)

    // Dismiss the entire flow
    self.dismiss()
  }
}

// MARK: - Preview Mock View Models

@MainActor
private func PreviewMatchViewModel() -> MatchViewModel {
  // Create a mock MatchViewModel for previews with proper initialization
  let mockViewModel = MatchViewModel(
    history: MockMatchHistoryService(),
    haptics: NoopHaptics())

  // Set up a mock match
  mockViewModel.newMatch = Match(homeTeam: "Arsenal", awayTeam: "Chelsea")
  mockViewModel.createMatch()

  return mockViewModel
}

@MainActor
private func PreviewMatchSetupViewModel() -> MatchSetupViewModel {
  let matchViewModel = PreviewMatchViewModel()
  return MatchSetupViewModel(matchViewModel: matchViewModel)
}

// MARK: - Mock Services for Previews

private class MockMatchHistoryService: MatchHistoryStoring {
  func loadAll() throws -> [CompletedMatch] { [] }
  func save(_ match: CompletedMatch) throws {
    print("Mock: Saved match \(match.match.homeTeam) vs \(match.match.awayTeam)")
  }

  func delete(id: UUID) throws { print("Mock: Deleted match \(id)") }
  func wipeAll() throws { print("Mock: Wiped all matches") }
}
