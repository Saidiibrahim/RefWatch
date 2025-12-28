//
//  WelcomeSlideTests.swift
//  RefWatchiOSTests
//

import RefWatchCore
import XCTest
@testable import RefWatchiOS

final class WelcomeSlideTests: XCTestCase {
  func testDefaultSlides_whenInvoked_returnsThreeUniqueSlides() {
    let theme = DefaultTheme().eraseToAnyTheme()

    let slides = WelcomeSlide.defaultSlides(theme: theme)

    XCTAssertEqual(slides.count, 3)
    XCTAssertEqual(Set(slides.map(\.id)).count, 3)
    XCTAssertEqual(
      slides.map(\.symbolName),
      ["applewatch", "iphone.gen3", "macbook.and.iphone"]
    )
    XCTAssertTrue(slides.allSatisfy { $0.symbolStyle.renderingMode == .palette })
  }

  func testDefaultSlides_whenResolvingPalette_returnsThemeDrivenColors() {
    let theme = DefaultTheme()
    let anyTheme = theme.eraseToAnyTheme()

    let slides = WelcomeSlide.defaultSlides(theme: anyTheme)
    let paletteSets = slides
      .map { $0.symbolStyle.colors(using: anyTheme) }

    XCTAssertTrue(paletteSets.allSatisfy { $0.isEmpty == false })
    XCTAssertEqual(paletteSets[0].count, 2)
    XCTAssertEqual(paletteSets[1].count, 2)
    XCTAssertEqual(paletteSets[2].count, 2)
  }
}
