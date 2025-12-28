//
//  OnboardingCardView.swift
//  RefWatchiOS
//
//  Renders a single welcome carousel slide with themed styling.
//

import RefWatchCore
import SwiftUI

struct OnboardingCardView: View {
  let slide: WelcomeSlide

  @Environment(\.theme) private var theme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(spacing: theme.spacing.stackLG) {
      icon
      VStack(spacing: theme.spacing.stackSM) {
        Text(slide.title)
          .font(theme.typography.heroTitle)
          .multilineTextAlignment(.center)
          .foregroundStyle(theme.colors.textPrimary)
        Text(slide.subtitle)
          .font(theme.typography.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(theme.colors.textSecondary)
      }
      .accessibilityElement(children: .combine)
    }
    .padding(.vertical, theme.spacing.stackXL)
    .padding(.horizontal, theme.spacing.stackXL)
    .frame(maxWidth: .infinity, minHeight: minHeight)
    .background(cardBackground)
    .accessibilityElement(children: .contain)
  }
}

private extension OnboardingCardView {
  var icon: some View {
    let colors = slide.symbolStyle.colors(using: theme)

    return Image(systemName: slide.symbolName)
      .symbolRenderingMode(slide.symbolStyle.renderingMode.symbolRenderingMode)
      .resizable()
      .scaledToFit()
      .modifier(ForegroundPaletteModifier(colors: colors))
      .frame(maxWidth: iconSize.width, maxHeight: iconSize.height)
      .accessibilityLabel(Text(slide.accessibilityLabel))
      .accessibilityAddTraits(.isImage)
  }

  var iconSize: CGSize {
    if dynamicTypeSize >= .accessibility2 {
      return CGSize(width: 120, height: 120)
    } else if dynamicTypeSize > .large {
      return CGSize(width: 140, height: 140)
    } else {
      return CGSize(width: 160, height: 160)
    }
  }

  var minHeight: CGFloat {
    dynamicTypeSize.isAccessibilitySize ? 420 : 360
  }

  var cardBackground: some View {
    RoundedRectangle(cornerRadius: 32, style: .continuous)
      .fill(theme.colors.backgroundElevated)
      .overlay(
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .stroke(theme.colors.outlineMuted)
      )
      .shadow(color: theme.colors.surfaceOverlay, radius: 24, x: 0, y: 16)
  }
}

private struct ForegroundPaletteModifier: ViewModifier {
  let colors: [Color]

  func body(content: Content) -> some View {
    switch colors.count {
    case 0:
      content
    case 1:
      content.foregroundStyle(colors[0])
    case 2:
      content.foregroundStyle(colors[0], colors[1])
    default:
      let tertiary = colors.count > 2 ? colors[2] : colors[1]
      content.foregroundStyle(colors[0], colors[1], tertiary)
    }
  }
}

#if DEBUG
#Preview {
  let theme = DefaultTheme()
  let slides = WelcomeSlide.defaultSlides(theme: theme.eraseToAnyTheme())
  VStack(spacing: 24) {
    ForEach(slides) { slide in
      OnboardingCardView(slide: slide)
    }
  }
  .padding()
  .background(theme.colors.backgroundPrimary.ignoresSafeArea())
  .theme(theme)
}
#endif
