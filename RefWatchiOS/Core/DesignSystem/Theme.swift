//
//  Theme.swift
//  RefWatchiOS
//
//  Minimal color palette to mirror watch semantics
//

import SwiftUI

enum AppTheme {
    static let goal = Color.green
    static let yellowCard = Color.yellow
    static let redCard = Color.red
    static let stoppage = Color.orange
    static let primaryAccent = Color.blue
}

extension View {
    func sectionCardStyle() -> some View {
        self
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

