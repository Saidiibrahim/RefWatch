import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct WorkoutDashboardView: View {
  @StateObject private var viewModel: WorkoutDashboardViewModel
  @State private var didLoad = false
  @State private var showError = false

  init(services: WorkoutServices) {
    _viewModel = StateObject(wrappedValue: WorkoutDashboardViewModel(services: services))
  }

  var body: some View {
    NavigationStack {
      List {
        if viewModel.authorization.state != .authorized {
          authorizationSection
        }

        overviewSection
        presetSection
        historySection
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Workout")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            viewModel.reloadPresets()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .refreshable {
        await viewModel.refresh()
      }
    }
    .onAppear {
      guard !didLoad else { return }
      didLoad = true
      viewModel.load()
    }
    .onChange(of: viewModel.errorMessage) { message in
      showError = message != nil
    }
    .alert("Workout Error", isPresented: $showError) {
      Button("OK", role: .cancel) {
        viewModel.errorMessage = nil
      }
    } message: {
      Text(viewModel.errorMessage ?? "An unexpected error occurred.")
    }
  }
}

private extension WorkoutDashboardView {
  var authorizationSection: some View {
    Section("Permissions") {
      VStack(alignment: .leading, spacing: 8) {
        Text(authorizationMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button(action: viewModel.requestAuthorization) {
          Text(viewModel.authorization.state == .notDetermined ? "Grant Health Access" : "Review Health Access")
        }
      }
      .padding(.vertical, 4)
    }
  }

  var overviewSection: some View {
    Section("Overview") {
      HStack {
        VStack(alignment: .leading) {
          Text("Presets")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(viewModel.presets.count)")
            .font(.title3)
            .fontWeight(.semibold)
        }
        Spacer()
        VStack(alignment: .leading) {
          Text("Recent Sessions")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(viewModel.recentSessions.count)")
            .font(.title3)
            .fontWeight(.semibold)
        }
      }
      .padding(.vertical, 4)

      Text("Start workouts on your Apple Watch to capture real-time metrics. Presets and history stay in sync once connectivity is established.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  var presetSection: some View {
    Section {
      if viewModel.presets.isEmpty {
        Text("Create your first workout preset to build repeatable training sessions.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.presets) { preset in
          NavigationLink {
            Text("Preset detail for \(preset.title) coming soon.")
              .padding()
              .navigationTitle(preset.title)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(preset.title)
                .font(.headline)
              Text(presetLine(preset))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
          }
        }
      }

      Button {
        // Placeholder for preset creation flow
      } label: {
        Label("New Preset", systemImage: "plus")
      }
    } header: {
      Text("Presets")
    }
  }

  var historySection: some View {
    Section("Recent Sessions") {
      if viewModel.recentSessions.isEmpty {
        Text("Completed workouts will appear here once synced from the watch.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.recentSessions) { session in
          NavigationLink {
            Text("Session detail for \(session.title) coming soon.")
              .padding()
              .navigationTitle(session.title)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(session.title)
                .font(.headline)
              Text(sessionLine(session))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
          }
        }
      }
    }
  }

  var authorizationMessage: String {
    switch viewModel.authorization.state {
    case .notDetermined:
      return "RefZone needs permission to read workouts, heart rate, and distance from Health to power the dashboard."
    case .denied:
      return "Health access is currently denied. Update permissions in the Health app to sync workouts."
    case .limited:
      return "Health access is limited. Allow all metrics for richer insights."
    case .authorized:
      return ""
    }
  }

  func presetLine(_ preset: WorkoutPreset) -> String {
    var parts: [String] = []
    let duration = preset.totalPlannedDuration
    if duration > 0 {
      parts.append(formatDuration(duration))
    }
    let distance = preset.totalPlannedDistance
    if distance > 0 {
      parts.append(formatDistance(distance))
    }
    parts.append(preset.kind.displayName)
    return parts.joined(separator: " • ")
  }

  func sessionLine(_ session: WorkoutSession) -> String {
    var parts: [String] = []
    if let duration = session.totalDuration ?? session.summary.duration {
      parts.append(formatDuration(duration))
    }
    if let distance = session.summary.totalDistance {
      parts.append(formatDistance(distance))
    }
    if let completed = session.endedAt {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      parts.append(formatter.localizedString(for: completed, relativeTo: Date()))
    }
    return parts.joined(separator: " • ")
  }

  func formatDuration(_ interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute]
    formatter.zeroFormattingBehavior = [.dropAll]
    return formatter.string(from: interval) ?? "0m"
  }

  func formatDistance(_ meters: Double) -> String {
    String(format: "%.1f km", meters / 1000)
  }
}
