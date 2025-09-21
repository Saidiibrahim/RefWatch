import SwiftUI
import RefWatchCore

struct ModeSwitcherView: View {
  let lastSelectedMode: AppMode?
  let allowDismiss: Bool
  let onSelect: (AppMode) -> Void
  let onDismiss: () -> Void

  init(
    lastSelectedMode: AppMode?,
    allowDismiss: Bool = true,
    onSelect: @escaping (AppMode) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.lastSelectedMode = lastSelectedMode
    self.allowDismiss = allowDismiss
    self.onSelect = onSelect
    self.onDismiss = onDismiss
  }

  var body: some View {
    NavigationStack {
      List {
        Section("Choose mode") {
          ForEach(AppMode.allCases, id: \.self) { mode in
            Button {
              onSelect(mode)
            } label: {
              ModeOptionRow(mode: mode, isLastUsed: mode == lastSelectedMode)
            }
            .buttonStyle(.plain)
          }
        }

        if let lastSelectedMode {
          Section("Last used") {
            Text(lastSelectedMode.displayName)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }
      .listStyle(.carousel)
      .navigationTitle("RefZone Mode")
      .toolbar {
        if allowDismiss {
          ToolbarItem(placement: .cancellationAction) {
            Button(action: onDismiss) {
              Label("Back", systemImage: "chevron.backward")
                .labelStyle(.titleAndIcon)
            }
          }
        }
      }
    }
  }
}

private struct ModeOptionRow: View {
  let mode: AppMode
  let isLastUsed: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: mode.systemImageName)
          .font(.system(size: 28, weight: .semibold))
          .foregroundColor(.accentColor)
          .frame(width: 40, height: 40)
        VStack(alignment: .leading, spacing: 2) {
          Text(mode.displayName)
            .font(.headline)
          Text(mode.tagline)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isLastUsed {
          Image(systemName: "arrow.uturn.left.circle")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
  }
}
