//
//  MatchLogsView.swift
//  RefZoneWatchOS
//
//  Description: View displaying chronological match events log for referee reference
//

import SwiftUI
import RefWatchCore

/// View displaying all match events in chronological order
struct MatchLogsView: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    var body: some View {
        NavigationStack {
            VStack {
                // Event list
                if matchViewModel.matchEvents.isEmpty {
                    // Empty state
                    VStack(spacing: theme.spacing.m) {
                        Image(systemName: "list.bullet")
                            .font(theme.typography.iconAccent)
                            .foregroundStyle(theme.colors.textSecondary)

                        Text("No Events Yet")
                            .font(theme.typography.cardHeadline)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("Match events will appear here as they occur")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, theme.components.cardHorizontalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Event list
                    List {
                        // Display events in reverse chronological order (most recent first)
                        ForEach(matchViewModel.matchEvents.reversed()) { event in
                            MatchEventRowView(event: event)
                        }
                    }
                    .listStyle(.carousel)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle("Match Log")
            .background(theme.colors.backgroundPrimary)
        }
        .background(theme.colors.backgroundPrimary.ignoresSafeArea())
    }
}

/// Individual match event row view
private struct MatchEventRowView: View {
    let event: MatchEventRecord
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            // Event header with time and period
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.formattedActualTime)
                        .font(theme.typography.cardMeta)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(event.matchTime)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                Text(event.periodDisplayName)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textInverted)
                    .padding(.horizontal, theme.spacing.xs)
                    .padding(.vertical, theme.spacing.xs / 2)
                    .background(
                        Capsule()
                            .fill(theme.colors.accentSecondary)
                    )
            }

            // Event details
            HStack(alignment: .top) {
                // Event type icon
                Image(systemName: eventIcon)
                    .font(theme.typography.iconAccent)
                    .foregroundStyle(eventColor)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    // Event type
                    Text(event.eventType.displayName)
                        .font(theme.typography.cardMeta)
                        .foregroundStyle(theme.colors.textPrimary)

                    // Team and details
                    HStack {
                        // Team badge (only if event has a team)
                        if let team = event.team {
                            Text(team.rawValue)
                                .font(theme.typography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.colors.textInverted)
                                .padding(.horizontal, theme.spacing.xs)
                                .padding(.vertical, theme.spacing.xs / 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.colors.badgeColor(for: team))
                                )
                        }

                        // Event description
                        Text(event.displayDescription)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, theme.spacing.xs)
    }
    
    /// Icon for the event type
    private var eventIcon: String {
        switch event.eventType {
        case .goal:
            return "soccerball"
        case .card(let details):
            return details.cardType == .yellow ? "square.fill" : "square.fill"
        case .substitution:
            return "arrow.up.arrow.down"
        case .kickOff:
            return "play.circle"
        case .periodStart:
            return "play.circle.fill"
        case .halfTime:
            return "pause.circle"
        case .periodEnd:
            return "stop.circle"
        case .matchEnd:
            return "stop.circle.fill"
        case .penaltiesStart:
            return "flag"
        case .penaltyAttempt(let details):
            return details.result == .scored ? "checkmark.circle" : "xmark.circle"
        case .penaltiesEnd:
            return "flag.checkered"
        }
    }
    
    /// Color for the event type
    private var eventColor: Color { theme.colors.color(for: event.eventType) }
}

#Preview {
    MatchLogsView(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
