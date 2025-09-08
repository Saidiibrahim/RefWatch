import XCTest
@testable import RefWatchiOS

final class ClerkAuthTests: XCTestCase {
    func testBestDisplayName_prefersFirstName_whenPresent() {
        let name = ClerkAuth.bestDisplayName(firstName: "  Alex  ", username: "alex_u", id: "u1")
        XCTAssertEqual(name, "Alex")
    }

    func testBestDisplayName_fallsBackToUsername_whenFirstNameMissing() {
        let name = ClerkAuth.bestDisplayName(firstName: nil, username: "  alex_u  ", id: "u1")
        XCTAssertEqual(name, "alex_u")
    }

    func testBestDisplayName_usesId_whenNoNameAvailable() {
        let name = ClerkAuth.bestDisplayName(firstName: "  ", username: "  ", id: "u1")
        XCTAssertEqual(name, "u1")
    }

    #if !canImport(Clerk)
    func testState_isSignedOut_withoutClerkModule() {
        let auth = ClerkAuth()
        XCTAssertEqual(auth.currentUserId, nil)
        // Note: cannot switch on enum with associated value easily; just assert signedOut via matching.
        switch auth.state {
        case .signedOut: XCTAssertTrue(true)
        default: XCTFail("Expected signedOut when Clerk is unavailable")
        }
    }
    #endif
}

