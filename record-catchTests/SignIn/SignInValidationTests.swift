import XCTest
@testable import record_catch

final class SignInValidationTests: XCTestCase {

    // MARK: - isBlank

    func test_isBlank_whenWhitespaceOnly_returnsTrue() {
        XCTAssertTrue(SignInValidation.isBlank("   \n\t"))
    }

    func test_isBlank_whenHasContent_returnsFalse() {
        XCTAssertFalse(SignInValidation.isBlank("a@b.com"))
    }

    // MARK: - Email

    func test_emailError_whenEmpty_returnsEmptyEmail() {
        XCTAssertEqual(SignInValidation.emailError(""), .emptyEmail)
    }

    func test_emailError_whenWhitespaceOnly_returnsEmptyEmail() {
        XCTAssertEqual(SignInValidation.emailError("   "), .emptyEmail)
    }

    func test_emailError_whenPresent_returnsNil() {
        // Presence-only: any non-blank string is accepted (no format regex).
        XCTAssertNil(SignInValidation.emailError("not-an-email"))
    }

    // MARK: - Password

    func test_passwordError_whenEmpty_returnsEmptyPassword() {
        XCTAssertEqual(SignInValidation.passwordError(""), .emptyPassword)
    }

    func test_passwordError_whenWhitespaceOnly_returnsEmptyPassword() {
        XCTAssertEqual(SignInValidation.passwordError("\t"), .emptyPassword)
    }

    func test_passwordError_whenPresent_returnsNil() {
        XCTAssertNil(SignInValidation.passwordError("hunter2"))
    }

    // MARK: - Form state mapping

    func test_formError_whenBothMissing_returnsMissingFields() {
        XCTAssertEqual(SignInValidation.formError(email: "", password: ""), .missingFields)
    }

    func test_formError_whenEmailMissing_returnsMissingFields() {
        XCTAssertEqual(SignInValidation.formError(email: " ", password: "pw"), .missingFields)
    }

    func test_formError_whenPasswordMissing_returnsMissingFields() {
        XCTAssertEqual(SignInValidation.formError(email: "a@b.com", password: ""), .missingFields)
    }

    func test_formError_whenBothPresent_returnsNone() {
        XCTAssertEqual(SignInValidation.formError(email: "a@b.com", password: "pw"), .none)
    }

    // MARK: - Localisation keys

    func test_fieldError_localizationKeys() {
        XCTAssertEqual(SignInFieldError.emptyEmail.localizationKey, "signIn.error.email.empty")
        XCTAssertEqual(SignInFieldError.emptyPassword.localizationKey, "signIn.error.password.empty")
    }

    func test_formError_localizationKeys() {
        XCTAssertNil(SignInFormError.none.localizationKey)
        XCTAssertNil(SignInFormError.missingFields.localizationKey)
        XCTAssertEqual(SignInFormError.invalidCredentials.localizationKey, "signIn.error.credentials")
    }
}
