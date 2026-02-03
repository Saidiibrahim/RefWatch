// TeamNameAbbreviationText.swift
// Displays a 3-letter team abbreviation with a long-press full-name toast.

import SwiftUI
import RefWatchCore

struct TeamNameAbbreviationText: View {
    @Environment(\.theme) private var theme

    let name: String
    let font: Font
    let color: Color
    let alignment: Alignment

    @State private var showFullName = false
    @State private var dismissTask: Task<Void, Never>?

    init(
        name: String,
        font: Font,
        color: Color,
        alignment: Alignment = .center
    ) {
        self.name = name
        self.font = font
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        ZStack(alignment: alignment) {
            Text(abbreviation)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .opacity(showFullName ? 0 : 1)

            if showFullName {
                Text(fullName)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, theme.spacing.s)
                    .padding(.vertical, theme.spacing.xs)
                    .background(
                        Capsule()
                            .fill(theme.colors.backgroundSecondary)
                            .overlay(
                                Capsule()
                                    .stroke(theme.colors.outlineMuted, lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            revealFullName()
        }
        .animation(.easeInOut(duration: 0.2), value: showFullName)
        .accessibilityLabel(fullName)
        .onDisappear {
            dismissTask?.cancel()
        }
    }
}

private extension TeamNameAbbreviationText {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var abbreviation: String {
        TeamNameAbbreviator.abbreviation(for: trimmedName)
    }

    var fullName: String {
        trimmedName.isEmpty ? abbreviation : trimmedName
    }

    func revealFullName() {
        dismissTask?.cancel()
        showFullName = true
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                showFullName = false
            }
        }
    }
}

private enum TeamNameAbbreviator {
    static func abbreviation(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "TBD" }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        if words.count > 1 {
            let initials = words.compactMap { word in
                word.first(where: { $0.isLetter || $0.isNumber })
            }
            let combined = String(initials.prefix(3))
            if combined.count == 3 {
                return combined.uppercased()
            }
        }

        let alphanumerics = trimmed.filter { $0.isLetter || $0.isNumber }
        let abbreviation = String(alphanumerics.prefix(3))
        return abbreviation.isEmpty ? "TBD" : abbreviation.uppercased()
    }
}

#Preview {
    VStack(spacing: 16) {
        TeamNameAbbreviationText(
            name: "Adelaide City",
            font: .headline,
            color: .white,
            alignment: .center
        )
        TeamNameAbbreviationText(
            name: "HOM",
            font: .headline,
            color: .white,
            alignment: .center
        )
    }
    .theme(DefaultTheme())
}
