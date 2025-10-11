import XCTest
@testable import RefZoneiOS

final class SupabaseCredentialValidatorTests: XCTestCase {
  private let validator = SupabaseCredentialValidator()

  func testValidate_withValidCredentials_succeeds() {
    XCTAssertNoThrow(try validator.validate(email: "ref@zone.app", password: "password123"))
  }

  func testValidate_whenEmailEmpty_throwsFormIncomplete() {
    XCTAssertThrowsError(try validator.validate(email: "", password: "password123")) { error in
      XCTAssertEqual(error as? SupabaseAuthError, .formIncomplete)
    }
  }

  func testValidate_whenEmailInvalid_throwsInvalidEmail() {
    XCTAssertThrowsError(try validator.validate(email: "invalid-email", password: "password123")) { error in
      XCTAssertEqual(error as? SupabaseAuthError, .invalidEmail)
    }
  }

  func testValidate_whenPasswordTooShort_throwsPasswordTooShort() {
    XCTAssertThrowsError(try validator.validate(email: "ref@zone.app", password: "short")) { error in
      XCTAssertEqual(error as? SupabaseAuthError, .passwordTooShort)
    }
  }
}
