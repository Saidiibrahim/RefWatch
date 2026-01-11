//
//  MatchActionsSheet.swift
//  RefWatchWatchOS
//
//  Description: Sheet presented when user long-presses on TimerView, showing match action options
//

import RefWatchCore
import SwiftUI
import WatchKit

/// Sheet view presenting four action options for referees during a match
struct MatchActionsSheet: View {
  let matchViewModel: MatchViewModel
  var lifecycle: MatchLifecycleCoordinator?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.theme) private var theme
  @Environment(\.watchLayoutScale) private var layout

  // State for controlling navigation destinations
  @State private var showingMatchLogs = false
  @State private var showingOptions = false
  @State private var showingEndHalfConfirmation = false

  var body: some View {
    // Determine end action title based on state
    let endActionTitle = computeEndActionTitle()

    NavigationStack {
      GeometryReader { proxy in
        let hPadding = self.theme.components.cardHorizontalPadding
        let colSpacing = self.theme.spacing.m
        let cellWidth = max(0, (proxy.size.width - (hPadding * 2) - colSpacing) / 2)

        ViewThatFits(in: .vertical) {
          // Standard spacing - for larger watches (45mm+)
          actionContent(
            cellWidth: cellWidth,
            horizontalSpacing: self.theme.spacing.l,
            verticalSpacing: self.theme.spacing.l,
            endActionTitle: endActionTitle)

          // Medium spacing
          actionContent(
            cellWidth: cellWidth,
            horizontalSpacing: self.theme.spacing.m,
            verticalSpacing: self.theme.spacing.m,
            endActionTitle: endActionTitle)

          // Small spacing
          actionContent(
            cellWidth: cellWidth,
            horizontalSpacing: self.theme.spacing.s,
            verticalSpacing: self.theme.spacing.s,
            endActionTitle: endActionTitle)

          // Extra small spacing for 42mm watches
          actionContent(
            cellWidth: cellWidth,
            horizontalSpacing: self.theme.spacing.xs,
            verticalSpacing: self.theme.spacing.xs,
            endActionTitle: endActionTitle)

          // Ultra-compact for very small screens
          ultraCompactContent(
            cellWidth: cellWidth,
            endActionTitle: endActionTitle)
        }
        .padding(.horizontal, hPadding)
        .padding(.top, 2)
        .padding(.bottom, self.layout.safeAreaBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      }
      .navigationTitle("Match Actions")
      .background(self.theme.colors.backgroundPrimary)
    }
    .tint(self.theme.colors.accentSecondary)
    .sheet(isPresented: self.$showingMatchLogs) {
      MatchLogsView(matchViewModel: self.matchViewModel)
    }
    .sheet(isPresented: self.$showingOptions) {
      MatchOptionsView(matchViewModel: self.matchViewModel, lifecycle: self.lifecycle)
    }
    .confirmationDialog(
      "",
      isPresented: self.$showingEndHalfConfirmation,
      titleVisibility: .hidden)
    {
      Button("Yes") {
        if self.matchViewModel.isFullTime {
          self.matchViewModel.finalizeMatch()
          DispatchQueue.main.async {
            self.lifecycle?.resetToStart()
            self.matchViewModel.resetMatch()
          }
          self.dismiss()
          return
        }

        let isFirstHalf = self.matchViewModel.currentPeriod == 1
        self.matchViewModel.endCurrentPeriod()
        if isFirstHalf {
          self.matchViewModel.isHalfTime = true
        }
        self.dismiss()
      }
      Button("No", role: .cancel) {}
    } message: {
      let shouldEndMatch = if self.matchViewModel.isFullTime {
        true
      } else if self.matchViewModel.currentMatch != nil,
                self.matchViewModel.currentPeriod == 2,
                (self.matchViewModel.currentMatch?.numberOfPeriods ?? 2) == 2
      {
        true
      } else {
        false
      }
      let prompt = shouldEndMatch
        ? "Are you sure you want to 'End Match'?"
        : "Are you sure you want to 'End Half'?"
      Text(prompt)
    }
    .background(self.theme.colors.backgroundPrimary.ignoresSafeArea())
  }
}

#Preview {
  MatchActionsSheet(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}

extension MatchActionsSheet {
  @ViewBuilder
  private func actionContent(
    cellWidth: CGFloat,
    horizontalSpacing: CGFloat,
    verticalSpacing: CGFloat,
    endActionTitle: String) -> some View
  {
    VStack(spacing: verticalSpacing) {
      // Top row remains: Match Log + Options. We keep spacing adaptive via ViewThatFits.
      self.topRow(cellWidth: cellWidth, spacing: horizontalSpacing)
      // Bottom row now has two cells: Undo + End Half/Match.
      self.bottomRow(cellWidth: cellWidth, spacing: horizontalSpacing, endActionTitle: endActionTitle)
      Spacer(minLength: 0)
    }
  }

  private func topRow(cellWidth: CGFloat, spacing: CGFloat) -> some View {
    HStack(spacing: spacing) {
      ActionGridItem(
        title: "Match Log",
        icon: "list.bullet",
        color: self.theme.colors.accentSecondary,
        showBackground: false)
      {
        self.showingMatchLogs = true
      }
      .frame(width: cellWidth)

      ActionGridItem(
        title: "Options",
        icon: "ellipsis.circle",
        color: self.theme.colors.accentMuted,
        showBackground: false)
      {
        self.showingOptions = true
      }
      .frame(width: cellWidth)
    }
  }

  // New bottom row for the 2x2 grid. Adds Undo placeholder and keeps End action logic.
  @ViewBuilder
  private func bottomRow(cellWidth: CGFloat, spacing: CGFloat, endActionTitle: String) -> some View {
    HStack(spacing: spacing) {
      // Undo placeholder — prints a debug message for now
      ActionGridItem(
        title: "Undo",
        icon: "arrow.uturn.backward.circle",
        color: self.theme.colors.accentMuted,
        showBackground: false)
      {
        if self.matchViewModel.undoLastUserEvent() {
          self.dismiss()
        } else {
          WKInterfaceDevice.current().play(.failure)
          print("[MatchActionsSheet] Undo tapped but no undoable event found")
        }
      }
      .frame(width: cellWidth)

      // End Half/Match action follows existing behavior
      if self.matchViewModel.isHalfTime {
        ActionGridItem(
          title: endActionTitle,
          icon: "arrow.right.circle",
          color: self.theme.colors.matchPositive,
          showBackground: false)
        {
          self.matchViewModel.endHalfTimeManually()
          self.dismiss()
        }
        .frame(width: cellWidth)
      } else {
        ActionGridItem(
          title: endActionTitle,
          icon: "checkmark.circle",
          color: self.theme.colors.matchPositive,
          showBackground: false)
        {
          // Check if we should skip confirmation (final period and time expired)
          if self.shouldSkipConfirmation {
            self.executeEndActionDirectly()
          } else {
            self.showingEndHalfConfirmation = true
          }
        }
        .frame(width: cellWidth)
      }
    }
  }

  // Ultra-compact layout for very small watches (42mm and smaller)
  @ViewBuilder
  private func ultraCompactContent(cellWidth: CGFloat, endActionTitle: String) -> some View {
    VStack(spacing: self.theme.spacing.xs) {
      // Top row with minimal spacing
      HStack(spacing: self.theme.spacing.xs) {
        self.compactActionItem(
          title: "Match Log",
          icon: "list.bullet",
          color: self.theme.colors.accentSecondary,
          width: cellWidth)
        {
          self.showingMatchLogs = true
        }

        self.compactActionItem(
          title: "Options",
          icon: "ellipsis.circle",
          color: self.theme.colors.accentMuted,
          width: cellWidth)
        {
          self.showingOptions = true
        }
      }

      // Bottom row with minimal spacing
      HStack(spacing: self.theme.spacing.xs) {
        self.compactActionItem(
          title: "Undo",
          icon: "arrow.uturn.backward.circle",
          color: self.theme.colors.accentMuted,
          width: cellWidth)
        {
          if self.matchViewModel.undoLastUserEvent() {
            self.dismiss()
          } else {
            WKInterfaceDevice.current().play(.failure)
            print("[MatchActionsSheet] Undo tapped but no undoable event found")
          }
        }

        // End Half/Match action follows existing behavior
        if self.matchViewModel.isHalfTime {
          self.compactActionItem(
            title: endActionTitle,
            icon: "arrow.right.circle",
            color: self.theme.colors.matchPositive,
            width: cellWidth)
          {
            self.matchViewModel.endHalfTimeManually()
            self.dismiss()
          }
        } else {
          self.compactActionItem(
            title: endActionTitle,
            icon: "checkmark.circle",
            color: self.theme.colors.matchPositive,
            width: cellWidth)
          {
            // Check if we should skip confirmation (final period and time expired)
            if self.shouldSkipConfirmation {
              self.executeEndActionDirectly()
            } else {
              self.showingEndHalfConfirmation = true
            }
          }
        }
      }

      Spacer(minLength: 0)
    }
  }

  // Compact action item for ultra-small layouts
  @ViewBuilder
  private func compactActionItem(
    title: String,
    icon: String,
    color: Color,
    width: CGFloat,
    action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      VStack(spacing: self.theme.spacing.xs) {
        ZStack {
          Circle()
            .fill(color)
            .frame(width: 36, height: 36) // Smaller than standard 44pt
          Image(systemName: icon)
            .font(.system(size: 16, weight: .medium)) // Smaller icon
            .foregroundStyle(self.theme.colors.textInverted)
        }

        Text(title)
          .font(self.theme.typography.cardMeta) // Smaller text
          .foregroundStyle(self.theme.colors.textPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(1) // Single line only
          .minimumScaleFactor(0.7) // More aggressive scaling
      }
      .frame(width: width, height: 52) // Much smaller height than standard 72pt
      .padding(.vertical, self.theme.spacing.xs)
      .padding(.horizontal, self.theme.spacing.xs)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(title))
  }

  // MARK: - Helper Methods

  /// Computes the end action title based on current match state
  private func computeEndActionTitle() -> String {
    if self.matchViewModel.isFullTime {
      return "End Match"
    }

    if self.matchViewModel.isHalfTime {
      return "Start Second Half"
    }

    // Check if we're on the final period
    guard let match = matchViewModel.currentMatch else {
      return "End Half"
    }

    let isFinalPeriod = self.matchViewModel.currentPeriod >= match.numberOfPeriods &&
      !match.hasExtraTime

    if isFinalPeriod {
      return "End Match"
    }

    // Show period-specific label
    if self.matchViewModel.currentPeriod == 1 {
      return "End 1st Half"
    } else if self.matchViewModel.currentPeriod == 2 {
      return "End 2nd Half"
    }

    return "End Half"
  }

  /// Checks if confirmation should be skipped (final period and time expired)
  private var shouldSkipConfirmation: Bool {
    guard let match = matchViewModel.currentMatch else {
      return false
    }

    // Only skip if on final period
    let isFinalPeriod = self.matchViewModel.currentPeriod >= match.numberOfPeriods &&
      !match.hasExtraTime

    if !isFinalPeriod {
      return false
    }

    // Check if period time is expired
    return self.isPeriodTimeExpired
  }

  /// Checks if period time remaining is expired (<= 0)
  private var isPeriodTimeExpired: Bool {
    let timeString = self.matchViewModel.periodTimeRemaining

    // Handle "--:--" format (indicates no time limit)
    if timeString == "--:--" {
      return false
    }

    // Parse "MM:SS" format
    let components = timeString.split(separator: ":")
    guard components.count == 2,
          let minutes = Int(components[0]),
          let seconds = Int(components[1])
    else {
      return false
    }

    // Check if total seconds <= 0
    return (minutes * 60 + seconds) <= 0
  }

  /// Executes end action directly without confirmation
  private func executeEndActionDirectly() {
    if self.matchViewModel.isFullTime {
      self.matchViewModel.finalizeMatch()
      DispatchQueue.main.async {
        self.lifecycle?.resetToStart()
        self.matchViewModel.resetMatch()
      }
      self.dismiss()
    } else {
      let isFirstHalf = self.matchViewModel.currentPeriod == 1
      self.matchViewModel.endCurrentPeriod()
      if isFirstHalf {
        self.matchViewModel.isHalfTime = true
      }
      self.dismiss()
    }
  }
}
