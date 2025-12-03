import XCTest
@testable import RefZone_Watch_App
import RefWatchCore

@MainActor
final class TimerFaceFactoryTests: XCTestCase {
    override func setUpWithError() throws {
        throw XCTSkip("TODO: watch simulator host fails to launch for TimerFaceFactoryTests; investigate paired device requirements / launch error 'Simulator device failed to launch com.IbrahimSaidi.RefZone.watchkitapp'.")
    }

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

    func testFactory_returnsView_forProStoppageFace() {
        // Given
        let vm = MatchViewModel(haptics: WatchHaptics())

        // When
        let view = TimerFaceFactory.view(for: .proStoppage, model: vm)

        // Then - compile/runtime sanity check by wrapping into Any
        _ = { () -> Any in view }()
        XCTAssertTrue(true)
    }

    func testFace_allowsHapticsEnvironmentInjection() {
        // Given
        let vm = MatchViewModel(haptics: WatchHaptics())

        // When
        let view = TimerFaceFactory
            .view(for: .standard, model: vm)
            .environment(\.haptics, NoopHaptics())

        // Then - compile/runtime sanity check by wrapping into Any
        _ = { () -> Any in view }()
        XCTAssertTrue(true)
    }
}
