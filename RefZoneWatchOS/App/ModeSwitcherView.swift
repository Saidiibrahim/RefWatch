import SwiftUI
import RefWatchCore

struct ModeSwitcherView: View {
  let currentMode: AppMode
  let lastSelectedMode: AppMode?
  let activeMode: AppMode?
  let allowDismiss: Bool
  let onSelect: (AppMode) -> Void
  let onDismiss: () -> Void

  init(
    currentMode: AppMode,
    lastSelectedMode: AppMode?,
    activeMode: AppMode? = nil,
    allowDismiss: Bool = true,
    onSelect: @escaping (AppMode) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.currentMode = currentMode
    self.lastSelectedMode = lastSelectedMode
    self.activeMode = activeMode
    self.allowDismiss = allowDismiss
    self.onSelect = onSelect
    self.onDismiss = onDismiss
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(AppMode.allCases, id: \.self) { mode in
          Button {
            onSelect(mode)
          } label: {
            ModeOptionCard(
              mode: mode,
              isCurrent: mode == currentMode,
              isLastUsed: mode == lastSelectedMode,
              isActive: mode == activeMode
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("mode-card-\(mode.rawValue)")
        }
      }
      .listStyle(.carousel)
      .navigationTitle("Select Mode")
      .toolbar {
        if allowDismiss {
          ToolbarItem(placement: .cancellationAction) {
            Button(action: onDismiss) {
              Image(systemName: "chevron.backward")
            }
            .accessibilityIdentifier("modeSwitcherBack")
          }
        }
      }
    }
  }
}

#Preview("Default") {
  ModeSwitcherView(
    currentMode: .match,
    lastSelectedMode: .match,
    activeMode: nil,
    allowDismiss: true,
    onSelect: { _ in },
    onDismiss: {}
  )
}

#Preview("First Run (no dismiss)") {
  ModeSwitcherView(
    currentMode: .match,
    lastSelectedMode: nil,
    activeMode: nil,
    allowDismiss: false,
    onSelect: { _ in },
    onDismiss: {}
  )
}

private struct ModeOptionCard: View {
  let mode: AppMode
  let isCurrent: Bool
  let isLastUsed: Bool
  let isActive: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: mode.systemImageName)
        .font(.system(size: 26, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(mode.displayName)
            .font(.headline)
          if isActive {
            StatusPill(title: "Active")
          }
        }

        Text(mode.tagline)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if isCurrent || isLastUsed {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .imageScale(.medium)
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }
}

private struct StatusPill: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(.ultraThinMaterial, in: Capsule())
  }
}
