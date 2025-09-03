//
//  LiveSampleData.swift
//  RefWatchiOS
//
//  Preview-only sample data for the Live session.
//

import SwiftUI

#if DEBUG
enum LiveSampleData {
    static func seed(_ session: LiveSessionModel, home: String = "HOM", away: String = "AWA") {
        session.simulateStart(home: home, away: away)
    }
}
#endif

