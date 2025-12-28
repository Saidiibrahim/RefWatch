import XCTest
@testable import RefWatchiOS

final class SupabaseAuthErrorTests: XCTestCase {
  func testMap_whenProviderDisabled_returnsThirdPartyUnavailable() {
    let error = NSError(
      domain: "Supabase",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "Provider (issuer \"https://accounts.google.com\") is not enabled"]
    )

    let mapped = SupabaseAuthError.map(error)
    XCTAssertEqual(mapped, .thirdPartyUnavailable(provider: SupabaseIDTokenCredentials.Provider.google.rawValue))
  }

  func testMap_whenEmailConfirmationRequired_returnsCustomError() {
    let error = NSError(
      domain: "Supabase",
      code: 0,
      userInfo: [NSLocalizedDescriptionKey: "Email confirmation required"]
    )

    let mapped = SupabaseAuthError.map(error)
    XCTAssertEqual(mapped, .emailConfirmationRequired(email: nil))
  }

  func testDescription_whenEmailProvided_embedsAddress() {
    let error = SupabaseAuthError.emailConfirmationRequired(email: "tester@example.com")
    XCTAssertEqual(error.errorDescription, "Check your inbox at tester@example.com to verify your account, then try signing in.")
  }
}
