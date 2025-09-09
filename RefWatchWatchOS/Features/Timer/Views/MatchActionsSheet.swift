//
//  MatchActionsSheet.swift
//  RefWatchWatchOS
//
//  Description: Sheet presented when user long-presses on TimerView, showing match action options
//

import SwiftUI
import RefWatchCore

/// Sheet view presenting three action options for referees during a match
struct MatchActionsSheet: View {
    let matchViewModel: MatchViewModel
    var lifecycle: MatchLifecycleCoordinator? = nil
    @Environment(\.dismiss) private var dismiss
    
    // State for controlling navigation destinations
    @State private var showingMatchLogs = false
    @State private var showingOptions = false
    @State private var showingEndHalfConfirmation = false
    
    var body: some View {
        // Two equal columns with compact spacing to fit on one screen
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
        
        NavigationStack {
            GeometryReader { proxy in
                let hPadding: CGFloat = 10
                let colSpacing: CGFloat = 10
                let cellWidth = (proxy.size.width - (hPadding * 2) - colSpacing) / 2
                
                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        // Top row: two primary actions
                        LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                            // Match Log
                            ActionGridItem(
                                title: "Match Log",
                                icon: "list.bullet",
                                color: .blue
                            ) {
                                showingMatchLogs = true
                            }
                            
                            // Options
                            ActionGridItem(
                                title: "Options",
                                icon: "ellipsis.circle",
                                color: .gray
                            ) {
                                showingOptions = true
                            }
                        }
                        
                        // Bottom row: single action centered to match column width
                        if matchViewModel.isHalfTime {
                            HStack {
                                Spacer(minLength: 0)
                                ActionGridItem(
                                    title: "End Half",
                                    icon: "checkmark.circle",
                                    color: .green,
                                    expandHorizontally: false
                                ) {
                                    matchViewModel.endHalfTimeManually()
                                    dismiss()
                                }
                                .frame(width: cellWidth)
                                Spacer(minLength: 0)
                            }
                        } else {
                            HStack {
                                Spacer(minLength: 0)
                                ActionGridItem(
                                    title: "End Half",
                                    icon: "checkmark.circle",
                                    color: .green,
                                    expandHorizontally: false
                                ) {
                                    showingEndHalfConfirmation = true
                                }
                                .frame(width: cellWidth)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, hPadding)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            }
            .navigationTitle("Match Actions")
        }
        .sheet(isPresented: $showingMatchLogs) {
            MatchLogsView(matchViewModel: matchViewModel)
        }
        .sheet(isPresented: $showingOptions) {
            MatchOptionsView(matchViewModel: matchViewModel, lifecycle: lifecycle)
        }
        .confirmationDialog(
            "",
            isPresented: $showingEndHalfConfirmation,
            titleVisibility: .hidden
        ) {
            Button("Yes") {
                let isFirstHalf = matchViewModel.currentPeriod == 1
                matchViewModel.endCurrentPeriod()
                if isFirstHalf {
                    matchViewModel.isHalfTime = true
                }
                dismiss()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text(
                (matchViewModel.currentMatch != nil && matchViewModel.currentPeriod == 2 && (matchViewModel.currentMatch?.numberOfPeriods ?? 2) == 2)
                ? "Are you sure you want to 'End Match'?"
                : "Are you sure you want to 'End Half'?"
            )
        }
    }
}


#Preview {
    MatchActionsSheet(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}

// MARK: - Private Grid Item

private struct ActionGridItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var expandHorizontally: Bool = true
    
    init(
        title: String,
        icon: String,
        color: Color,
        expandHorizontally: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.expandHorizontally = expandHorizontally
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: expandHorizontally ? .infinity : nil, minHeight: 72)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
