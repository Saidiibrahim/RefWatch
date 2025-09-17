import SwiftUI
import RefWatchCore
import RefWorkoutCore

struct AppRootView: View {
  @EnvironmentObject private var appModeController: AppModeController
  @Environment(\.workoutServices) private var workoutServices
  @State private var showModePicker = false
  @State private var workoutViewID = UUID()

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Group {
        switch appModeController.currentMode {
        case .match:
          ContentView()
        case .workout:
          WorkoutRootView(
            services: workoutServices,
            appModeController: appModeController
          )
          .id(workoutViewID)
        }
      }

      ModeSwitcherButton(currentMode: appModeController.currentMode) {
        showModePicker = true
      }
      .padding(.top, 8)
      .padding(.trailing, 8)
    }
    .sheet(isPresented: $showModePicker) {
      NavigationStack {
        ModePickerSheet(isPresented: $showModePicker)
          .environmentObject(appModeController)
      }
    }
    .onChange(of: appModeController.currentMode) { mode in
      if mode == .workout {
        workoutViewID = UUID()
      }
    }
  }
}

private struct ModeSwitcherButton: View {
  let currentMode: AppMode
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(currentMode.displayName, systemImage: currentMode.systemImageName)
        .labelStyle(.iconOnly)
        .padding(8)
        .background(.ultraThinMaterial, in: Circle())
    }
    .buttonStyle(.plain)
  }
}

private struct ModePickerSheet: View {
  @EnvironmentObject private var appModeController: AppModeController
  @Binding var isPresented: Bool

  var body: some View {
    List(AppMode.allCases, id: \.self) { mode in
      Button {
        appModeController.select(mode)
        isPresented = false
      } label: {
        HStack {
          Image(systemName: mode.systemImageName)
            .foregroundColor(.accentColor)
          VStack(alignment: .leading) {
            Text(mode.displayName)
            Text(mode.tagline)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if appModeController.currentMode == mode {
            Image(systemName: "checkmark")
              .foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
    }
    .listStyle(.carousel)
    .navigationTitle("Choose Mode")
  }
}
