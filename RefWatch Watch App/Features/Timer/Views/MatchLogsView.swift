//
//  MatchLogsView.swift
//  RefWatch Watch App
//
//  Description: View displaying chronological match events log for referee reference
//

import SwiftUI
import RefWatchCore

/// View displaying all match events in chronological order
struct MatchLogsView: View {
    let matchViewModel: MatchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // Clean header with centered title
                Text("Match Log")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // Event list
                if matchViewModel.matchEvents.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        
                        Text("No Events Yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Match events will appear here as they occur")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
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
                }
            }
        }
    }
}

/// Individual match event row view
private struct MatchEventRowView: View {
    let event: MatchEventRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Event header with time and period
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.formattedActualTime)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(event.matchTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(event.periodDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                    )
            }
            
            // Event details
            HStack(alignment: .top) {
                // Event type icon
                Image(systemName: eventIcon)
                    .font(.system(size: 16))
                    .foregroundColor(eventColor)
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Event type
                    Text(event.eventType.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Team and details
                    HStack {
                        // Team badge (only if event has a team)
                        if let team = event.team {
                            Text(team.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(team == .home ? Color.blue : Color.red)
                                )
                        }
                        
                        // Event description
                        Text(event.displayDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
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
    private var eventColor: Color {
        switch event.eventType {
        case .goal:
            return .green
        case .card(let details):
            return details.cardType == .yellow ? .yellow : .red
        case .substitution:
            return .blue
        case .kickOff, .periodStart:
            return .green
        case .halfTime:
            return .orange
        case .periodEnd, .matchEnd:
            return .red
        case .penaltiesStart:
            return .orange
        case .penaltyAttempt(let details):
            return details.result == .scored ? .green : .red
        case .penaltiesEnd:
            return .green
        }
    }
}

#Preview {
    MatchLogsView(matchViewModel: MatchViewModel(haptics: WatchHaptics()))
}
