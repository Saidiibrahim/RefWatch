//
//  NavigationRowLabel.swift
//  RefZoneWatchOS
//
//  Description: Reusable navigation row label matching SettingsNavigationRow style.
//  Provides consistent styling for list-based navigation across Match, Workout, and Settings.
//

import SwiftUI
import RefWatchCore

// MARK: - NavigationRowLabel
/// A reusable label component for navigation rows with consistent styling.
///
/// Matches the visual language of `SettingsNavigationRow`:
/// - minHeight 72pt
/// - Icon sized `.title2` in `accentSecondary`
/// - Title using `cardHeadline` typography
/// - Optional subtitle in `cardMeta` typography
/// - Optional chevron or custom accessory view
///
/// Usage:
/// ```swift
/// NavigationLink {
///   DestinationView()
/// } label: {
///   NavigationRowLabel(title: "Settings", icon: "gear")
/// }
/// ```

struct NavigationRowLabel: View {
  @Environment(\.theme) private var theme

  let title: String
  let subtitle: String?
  let icon: String?
  let showChevron: Bool

  init(
    title: String,
    subtitle: String? = nil,
    icon: String? = nil,
    showChevron: Bool = false
  ) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.showChevron = showChevron
  }

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: theme.spacing.m) {
        if let icon {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(theme.colors.accentSecondary)
        }

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(title)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)

          if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)
              .lineLimit(1)
          }
        }

        if showChevron {
          Image(systemName: "chevron.forward")
            .font(theme.typography.iconSecondary)
            .foregroundStyle(theme.colors.textSecondary)
        }
      }
    }
  }
}

// MARK: - NavigationRowLabelWithAccessory
/// A variant that accepts a custom accessory view (e.g., ProgressView, Badge, etc.)
struct NavigationRowLabelWithAccessory<Accessory: View>: View {
  @Environment(\.theme) private var theme

  let title: String
  let subtitle: String?
  let icon: String?
  let accessory: Accessory

  init(
    title: String,
    subtitle: String? = nil,
    icon: String? = nil,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.accessory = accessory()
  }

  var body: some View {
    ThemeCardContainer(role: .secondary, minHeight: 72) {
      HStack(spacing: theme.spacing.m) {
        if let icon {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(theme.colors.accentSecondary)
        }

        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Text(title)
            .font(theme.typography.cardHeadline)
            .foregroundStyle(theme.colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)

          if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
              .font(theme.typography.cardMeta)
              .foregroundStyle(theme.colors.textSecondary)
              .lineLimit(1)
          }
        }

        accessory
      }
    }
  }
}

#Preview("Navigation Row Labels") {
  NavigationStack {
    List {
      Section("Basic") {
        NavigationLink {
          Text("Destination")
        } label: {
          NavigationRowLabel(title: "Start", icon: "flag.checkered")
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section("With Subtitle") {
        NavigationLink {
          Text("Destination")
        } label: {
          NavigationRowLabel(
            title: "Outdoor Run",
            subtitle: "Auto-pause + splits",
            icon: "figure.run"
          )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section("With Chevron") {
        NavigationLink {
          Text("Destination")
        } label: {
          NavigationRowLabel(
            title: "History",
            icon: "clock.arrow.circlepath",
            showChevron: true
          )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section("With Custom Accessory") {
        Button {} label: {
          NavigationRowLabelWithAccessory(
            title: "Loading",
            icon: "gear"
          ) {
            ProgressView()
              .progressViewStyle(.circular)
          }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.carousel)
    .scrollContentBackground(.hidden)
    .scenePadding(.horizontal)
  }
  .theme(DefaultTheme())
}

