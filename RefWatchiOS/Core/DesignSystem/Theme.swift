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

    enum Typography {
        static let timerXL: Font = .system(size: 44, weight: .bold, design: .rounded)
        static let timerSub: Font = .system(size: 18, weight: .medium, design: .rounded)
        static let timerStoppage: Font = .system(size: 16, weight: .medium, design: .rounded)
        static let header: Font = .headline
        static let subheader: Font = .title3
        static let scoreXL: Font = .system(size: 40, weight: .bold, design: .rounded)
        static let scoreL: Font = .system(size: 34, weight: .bold, design: .rounded)
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    enum Corners {
        static let s: CGFloat = 10
        static let m: CGFloat = 12
    }

    enum Buttons {
        static let heightM: CGFloat = 48
    }
}

extension View {
    func sectionCardStyle() -> some View {
        self
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
