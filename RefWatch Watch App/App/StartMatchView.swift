//
//  StartMatchView.swift
//  RefWatch
//
//  Created by Ibrahim Saidi on 11/1/2025.
//

import SwiftUI

@Observable final class StartMatchViewModel {
    // Using zod for potential type validation - Hypothetical usage in Swift
    // let matchSchema = z.object(["startTime": z.date().optional(), "duration": z.number()])

    // This is a wrapper around the actual MatchViewModel or direct logic
    // For demonstration only, we keep it simple
    var matchViewModel = MatchViewModel()

    func onStartMatch() {
        print("[DEBUG] onStartMatch triggered")
        matchViewModel.startMatch()
    }
}

struct StartMatchView: View {
    // We store the reference type as a let constant (rule: PropWrap).
    let model: StartMatchViewModel

    var body: some View {
        VStack {
            Text("Kick off your match").font(.headline).padding()
            Button("Start Match") {
                print("[DEBUG] Start button tapped in StartMatchView")
                model.onStartMatch()
            }
            .buttonStyle(.borderedProminent)

            Text(model.matchViewModel.formattedElapsedTime)
                .font(.title2)
                .padding()
        }
        .navigationTitle("Start Match")
    }
}

