import XCTest
@testable import RefWatch_Watch_App

final class TimerFaceFactoryTests: XCTestCase {
    func testMatchViewModel_conformsToTimerFaceModel() {
        // Given
        let vm = MatchViewModel(haptics: WatchHaptics())

        // Then
        XCTAssertTrue((vm as Any) is TimerFaceModel)
    }

    func testFactory_returnsView_forStandardFace() {
        // Given
        let vm = MatchViewModel(haptics: WatchHaptics())

        // When
        let view = TimerFaceFactory.view(for: .standard, model: vm)

        // Then - compile/runtime sanity check by wrapping into Any
        _ = { () -> Any in view }()
        XCTAssertTrue(true)
    }
}

