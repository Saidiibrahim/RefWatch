//
//  RefZoneWidgets.swift
//  RefZoneWidgets
//
//  Created by Ibrahim Saidi on 15/9/2025.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    private let store = LiveActivityStateStore()

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), state: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let state = store.read()
        completion(WidgetEntry(date: Date(), state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let now = Date()
        let state = store.read()

        // Single-entry timeline; updates are driven by publisher reloads.
        let entry = WidgetEntry(date: now, state: state)

        // While running, tick after the expected period end to flip state to paused/next.
        if let s = state, s.isPaused == false, let expectedEnd = s.expectedPeriodEnd {
            completion(Timeline(entries: [entry], policy: .after(expectedEnd)))
        } else {
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

// MARK: - Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let state: LiveActivityState?
}

// MARK: - Family-aware host view

struct MatchWidgetView: View {
    let state: LiveActivityState?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularView(state: state)
        case .accessoryCircular:
            CircularView(state: state)
        default:
            RectangularView(state: state)
        }
    }
}

// MARK: - Widget

struct RefZoneWidgets: Widget {
    let kind: String = "RefZoneWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                MatchWidgetView(state: entry.state)
                    .containerBackground(.fill.tertiary, for: .widget)
                    .widgetURL(URL(string: "refzone://timer"))
            } else {
                MatchWidgetView(state: entry.state)
                    .padding()
                    .background()
                    .widgetURL(URL(string: "refzone://timer"))
            }
        }
        .configurationDisplayName("RefZone")
        .description("Glance match time and pause or resume instantly.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
