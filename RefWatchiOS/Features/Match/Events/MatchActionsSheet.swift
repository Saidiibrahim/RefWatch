//
//  MatchActionsSheet.swift
//  RefWatchiOS
//
//  iOS actions hub for recording detailed match events.
//

import RefWatchCore
import SwiftUI

struct MatchActionsSheet: View {
  let matchViewModel: MatchViewModel
  var onRecordGoal: (() -> Void)?
  var onRecordCard: (() -> Void)?
  var onRecordSubstitution: (() -> Void)?
  var onStartNextPeriod: (() -> Void)?
  var onEndPeriod: (() -> Void)?
  var onFinishMatch: (() -> Void)?

  @State private var showGoalFlow = false
  @State private var showCardFlow = false
  @State private var showSubFlow = false
  @State private var showEndPeriodConfirm = false
  @State private var showAdvanceConfirm = false
  @State private var showFullTime = false
  @State private var showResetConfirm = false
  @State private var showAbandonConfirm = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section("Events") {
          Button {
            if let onRecordGoal {
              onRecordGoal()
            } else {
              self.showGoalFlow = true
            }
          } label: {
            Label("Record Goal", systemImage: "soccerball")
          }

          Button {
            if let onRecordCard {
              onRecordCard()
            } else {
              self.showCardFlow = true
            }
          } label: {
            Label("Record Card", systemImage: "rectangle.fill")
          }

          Button {
            if let onRecordSubstitution {
              onRecordSubstitution()
            } else {
              self.showSubFlow = true
            }
          } label: {
            Label("Record Substitution", systemImage: "arrow.up.arrow.down")
          }
        }

        Section("Period") {
          if self.matchViewModel.isMatchInProgress {
            Button {
              self.matchViewModel.pauseMatch()
            } label: { Label("Pause Timer", systemImage: "pause.circle") }
          } else if !self.matchViewModel.isFullTime {
            Button {
              self.matchViewModel.resumeMatch()
            } label: { Label("Resume Timer", systemImage: "play.circle") }
          }
          periodButtons
        }

        Section("Finish") {
          Button(role: .destructive) {
            if let onFinishMatch {
              onFinishMatch()
            } else {
              self.showFullTime = true
            }
          } label: { Label("Finish Match", systemImage: "flag.checkered") }
        }

        Section("Options") {
          Button {
            self.showResetConfirm = true
          } label: { Label("Reset Match", systemImage: "arrow.counterclockwise") }

          Button(role: .destructive) {
            self.showAbandonConfirm = true
          } label: { Label("Abandon Match", systemImage: "xmark.circle") }
        }
      }
      .navigationTitle("Match Actions")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: self.$showGoalFlow) {
        GoalEventFlowView(matchViewModel: self.matchViewModel)
      }
      .sheet(isPresented: self.$showCardFlow) {
        CardEventFlowView(matchViewModel: self.matchViewModel)
      }
      .sheet(isPresented: self.$showSubFlow) {
        SubstitutionEventFlowView(matchViewModel: self.matchViewModel)
      }
      .sheet(isPresented: self.$showFullTime) {
        FullTimeView_iOS(matchViewModel: self.matchViewModel)
      }
      .confirmationDialog(
        "",
        isPresented: self.$showEndPeriodConfirm,
        titleVisibility: .hidden)
      {
        Button("Yes") {
          let isFinalReg = self.isFinalRegulationEnd
          self.matchViewModel.endCurrentPeriod()
          if isFinalReg {
            // When this ends the match in regulation, the timer will present Full Time
          }
        }
        Button("No", role: .cancel) {}
      } message: {
        Text(self.endPeriodConfirmationMessage)
      }
      .confirmationDialog(
        "",
        isPresented: self.$showAdvanceConfirm,
        titleVisibility: .hidden)
      {
        Button("Yes") {
          self.matchViewModel.startNextPeriod()
        }
        Button("No", role: .cancel) {}
      } message: {
        Text("Start next period now?")
      }
      .alert("Reset Match", isPresented: self.$showResetConfirm) {
        Button("Cancel", role: .cancel) {}
        Button("Reset", role: .destructive) {
          self.matchViewModel.resetMatch()
          self.dismiss()
        }
      } message: {
        Text("This will reset score, cards, and events. This cannot be undone.")
      }
      .alert("Abandon Match", isPresented: self.$showAbandonConfirm) {
        Button("Cancel", role: .cancel) {}
        Button("Abandon", role: .destructive) {
          self.matchViewModel.abandonMatch()
          self.dismiss()
        }
      } message: {
        Text("This will end the match immediately and record it as abandoned.")
      }
    }
  }
}

extension MatchActionsSheet {
  private var isFinalRegulationEnd: Bool {
    guard let match = self.matchViewModel.currentMatch else { return false }
    return self.matchViewModel.currentPeriod == match.numberOfPeriods && match.hasExtraTime == false
  }

  private var endPeriodConfirmationMessage: String {
    if self.isFinalRegulationEnd {
      return "Are you sure you want to 'End Match'?"
    }
    return "Are you sure you want to 'End Half'?"
  }

  @ViewBuilder
  private var periodButtons: some View {
    if self.matchViewModel.isMatchInProgress {
      Button(role: .destructive) {
        if let onEndPeriod {
          onEndPeriod()
          self.dismiss()
        } else {
          self.showEndPeriodConfirm = true
        }
      } label: { Label("End Current Period", systemImage: "stop.circle") }
    } else if self.matchViewModel.waitingForHalfTimeStart
      || self.matchViewModel.waitingForSecondHalfStart
      || self.matchViewModel.waitingForET1Start
      || self.matchViewModel.waitingForET2Start
    {
      Button {
        if let onStartNextPeriod {
          onStartNextPeriod()
          self.dismiss()
        } else {
          self.showAdvanceConfirm = true
        }
      } label: { Label("Start Next Period", systemImage: "forward.fill") }
    }
  }
}
