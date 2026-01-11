//
//  WelcomeSlide.swift
//  RefWatchiOS
//
//  Represents a single onboarding slide in the welcome carousel.
//

import RefWatchCore
import SwiftUI

/// Describes the copy and iconography for a welcome carousel slide.
struct WelcomeSlide: Identifiable, Hashable {
  /// Defines which theme colors should be applied to the SF Symbol palette.
  enum PaletteColorToken: Hashable {
    case accentPrimary
    case accentSecondary
    case accentMuted
    case textSecondary

    func resolve(using palette: ColorPalette) -> Color {
      switch self {
      case .accentPrimary: palette.accentPrimary
      case .accentSecondary: palette.accentSecondary
      case .accentMuted: palette.accentMuted
      case .textSecondary: palette.textSecondary
      }
    }
  }

  /// Captures SF Symbol styling details for consistent rendering.
  struct SymbolStyle: Hashable {
    enum RenderingVariant: Hashable {
      case palette
      case hierarchical
      case monochrome

      var symbolRenderingMode: SwiftUI.SymbolRenderingMode {
        switch self {
        case .palette: .palette
        case .hierarchical: .hierarchical
        case .monochrome: .monochrome
        }
      }
    }

    let renderingMode: RenderingVariant
    let paletteTokens: [PaletteColorToken]

    func colors(using theme: AnyTheme) -> [Color] {
      self.paletteTokens.map { $0.resolve(using: theme.colors) }
    }
  }

  let id: String
  let title: String
  let subtitle: String
  let symbolName: String
  let symbolStyle: SymbolStyle
  let accessibilityLabel: String
  let analyticsIdentifier: String?
}

extension WelcomeSlide {
  /// Provides the default set of onboarding slides shown in the welcome carousel.
  ///
  /// - Parameter theme: The active theme providing palette colors for SF Symbols.
  /// - Returns: Three slides that highlight watch, iPhone, and web workflows.
  static func defaultSlides(theme: AnyTheme) -> [WelcomeSlide] {
    let watchStyle = SymbolStyle(
      renderingMode: .palette,
      paletteTokens: [.accentSecondary, .accentMuted])
    let iphoneStyle = SymbolStyle(
      renderingMode: .palette,
      paletteTokens: [.accentPrimary, .textSecondary])
    let webStyle = SymbolStyle(
      renderingMode: .palette,
      paletteTokens: [.accentSecondary, .accentPrimary])

    // Touch the palette to silence unused parameter warnings until dynamic theming evolves.
    _ = [watchStyle, iphoneStyle, webStyle].map { $0.colors(using: theme) }

    // TODO: Localize strings once translations are available.
    return [
      WelcomeSlide(
        id: "watch",
        title: NSLocalizedString(
          "welcome.carousel.watch.title",
          value: "Match control on your wrist",
          comment: "Title for the Apple Watch onboarding slide"),
        subtitle: NSLocalizedString(
          "welcome.carousel.watch.subtitle",
          value: "Start matches, track stoppage, and log incidents directly from Apple Watch.",
          comment: "Subtitle for the Apple Watch onboarding slide"),
        symbolName: "applewatch",
        symbolStyle: watchStyle,
        accessibilityLabel: NSLocalizedString(
          "welcome.carousel.watch.accessibility",
          value: "Apple Watch showing live match timer",
          comment: "Accessibility label describing the Apple Watch onboarding slide illustration"),
        analyticsIdentifier: "welcome_slide_watch"),
      WelcomeSlide(
        id: "iphone",
        title: NSLocalizedString(
          "welcome.carousel.iphone.title",
          value: "Insights that travel with you",
          comment: "Title for the iPhone onboarding slide"),
        subtitle: NSLocalizedString(
          "welcome.carousel.iphone.subtitle",
          value: "Review performance trends, hydrate your prep, and stay synced across every match.",
          comment: "Subtitle for the iPhone onboarding slide"),
        symbolName: "iphone.gen3",
        symbolStyle: iphoneStyle,
        accessibilityLabel: NSLocalizedString(
          "welcome.carousel.iphone.accessibility",
          value: "iPhone displaying officiating insights",
          comment: "Accessibility label describing the iPhone onboarding slide illustration"),
        analyticsIdentifier: "welcome_slide_iphone"),
      WelcomeSlide(
        id: "web",
        title: NSLocalizedString(
          "welcome.carousel.web.title",
          value: "Plan and collaborate anywhere",
          comment: "Title for the web dashboard onboarding slide"),
        subtitle: NSLocalizedString(
          "welcome.carousel.web.subtitle",
          value: "Coordinate crews, share match libraries, and sync with the web dashboard.",
          comment: "Subtitle for the web dashboard onboarding slide"),
        symbolName: "macbook.and.iphone",
        symbolStyle: webStyle,
        accessibilityLabel: NSLocalizedString(
          "welcome.carousel.web.accessibility",
          value: "MacBook and iPhone illustrating synced dashboards",
          comment: "Accessibility label describing the web dashboard onboarding slide illustration"),
        analyticsIdentifier: "welcome_slide_web"),
    ]
  }
}
