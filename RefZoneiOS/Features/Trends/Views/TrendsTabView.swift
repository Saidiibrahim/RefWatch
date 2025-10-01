//
//  TrendsTabView.swift
//  RefZoneiOS
//
//  Placeholder analytics overview (static summaries)
//

import SwiftUI

struct TrendsTabView: View {
    @EnvironmentObject private var authController: SupabaseAuthController

    var body: some View {
        NavigationStack {
            Group {
                if authController.isSignedIn {
                    List {
                        Section("Overview (Last 20 Matches)") {
                            metricRow(title: "Average Cards", value: "3.2")
                            metricRow(title: "Average Stoppage (min)", value: "5.4")
                            metricRow(title: "Penalty Conversion", value: "78%")
                        }

                        Section("Discipline") {
                            HStack { Text("Yellow / Red Ratio"); Spacer(); Text("5.1 : 1").foregroundStyle(.secondary) }
                            HStack { Text("First Card Time"); Spacer(); Text("34’").foregroundStyle(.secondary) }
                        }

                        Section("Scoring") {
                            HStack { Text("Goals in 15’ blocks"); Spacer(); Text("3 • 5 • 6 • 2").foregroundStyle(.secondary) }
                        }
                    }
                } else {
                    SignedOutFeaturePlaceholder(
                        description: "Sign in to unlock match trends and officiating insights on iPhone."
                    )
                }
            }
            .navigationTitle("Trends")
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).font(.headline) }
    }
}

#Preview { TrendsTabView() }
