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

    // MARK: - normalisedEmail

    func test_normalisedEmail_trimsWhitespace() {
        XCTAssertEqual(SignInValidation.normalisedEmail("  a@b.com  "), "a@b.com")
    }

    func test_normalisedEmail_lowercases() {
        XCTAssertEqual(SignInValidation.normalisedEmail("A@B.COM"), "a@b.com")
    }

    func test_normalisedEmail_trimsAndLowercasesTogether() {
        XCTAssertEqual(SignInValidation.normalisedEmail("  A@B.Com  "), "a@b.com")
    }

    // MARK: - isValidEmailFormat

    func test_isValidEmailFormat_withSimpleAddress_returnsTrue() {
        XCTAssertTrue(SignInValidation.isValidEmailFormat("a@b.com"))
    }

    func test_isValidEmailFormat_withSubdomain_returnsTrue() {
        XCTAssertTrue(SignInValidation.isValidEmailFormat("skipper@vessel.example.com"))
    }

    func test_isValidEmailFormat_withNoAtSign_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("not-an-email"))
    }

    func test_isValidEmailFormat_withTwoAtSigns_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("a@b@c.com"))
    }

    func test_isValidEmailFormat_withEmptyLocalPart_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("@b.com"))
    }

    func test_isValidEmailFormat_withNoDomainDot_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("a@b"))
    }

    func test_isValidEmailFormat_withEmptyDomainLabel_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("a@b..com"))
    }

    func test_isValidEmailFormat_withWhitespace_returnsFalse() {
        XCTAssertFalse(SignInValidation.isValidEmailFormat("a b@c.com"))
    }

    // MARK: - Email field error

    func test_emailError_whenEmpty_returnsEmptyEmail() {
        XCTAssertEqual(SignInValidation.emailError(""), .emptyEmail)
    }

    func test_emailError_whenWhitespaceOnly_returnsEmptyEmail() {
        XCTAssertEqual(SignInValidation.emailError("   "), .emptyEmail)
    }

    func test_emailError_whenInvalidFormat_returnsInvalidEmailFormat() {
        XCTAssertEqual(SignInValidation.emailError("not-an-email"), .invalidEmailFormat)
    }

    func test_emailError_whenValid_returnsNil() {
        XCTAssertNil(SignInValidation.emailError("a@b.com"))
    }

    func test_emailError_whenValidWithUntrimmedUppercase_returnsNil() {
        // Format is checked against the *normalised* email (ticket: not case-sensitive, spaces
        // trimmed automatically).
        XCTAssertNil(SignInValidation.emailError("  A@B.COM  "))
    }

    // MARK: - Password

    func test_passwordError_whenEmpty_returnsEmptyPassword() {
        XCTAssertEqual(SignInValidation.passwordError(""), .emptyPassword)
    }

    func test_passwordError_whenWhitespaceOnly_returnsEmptyPassword() {
        XCTAssertEqual(SignInValidation.passwordError("\t"), .emptyPassword)
    }

    func test_passwordError_whenPresent_returnsNil() {
        XCTAssertNil(SignInValidation.passwordError("TestPassword123"))
    }

    func test_passwordError_withLeadingTrailingSpaces_stillAccepted() {
        // Passwords are never trimmed — whitespace may be deliberate.
        XCTAssertNil(SignInValidation.passwordError("  TestPassword123  "))
    }

    // MARK: - Form state mapping

    func test_formError_whenBothMissing_returnsMissingOrInvalidFields() {
        XCTAssertEqual(SignInValidation.formError(email: "", password: ""), .missingOrInvalidFields)
    }

    func test_formError_whenEmailMissing_returnsMissingOrInvalidFields() {
        XCTAssertEqual(SignInValidation.formError(email: " ", password: "pw"), .missingOrInvalidFields)
    }

    func test_formError_whenPasswordMissing_returnsMissingOrInvalidFields() {
        XCTAssertEqual(SignInValidation.formError(email: "a@b.com", password: ""), .missingOrInvalidFields)
    }

    func test_formError_whenEmailInvalidFormat_returnsMissingOrInvalidFields() {
        XCTAssertEqual(SignInValidation.formError(email: "not-an-email", password: "pw"), .missingOrInvalidFields)
    }

    func test_formError_whenBothPresentAndValid_returnsNone() {
        XCTAssertEqual(SignInValidation.formError(email: "a@b.com", password: "pw"), .none)
    }

    // MARK: - Localisation keys

    func test_fieldError_localizationKeys() {
        XCTAssertEqual(SignInFieldError.emptyEmail.localizationKey, "signIn.error.email.empty")
        XCTAssertEqual(SignInFieldError.invalidEmailFormat.localizationKey, "signIn.error.email.invalid")
        XCTAssertEqual(SignInFieldError.emptyPassword.localizationKey, "signIn.error.password.empty")
    }

    func test_formError_localizationKeys() {
        XCTAssertNil(SignInFormError.none.localizationKey)
        XCTAssertNil(SignInFormError.missingOrInvalidFields.localizationKey)
        XCTAssertEqual(SignInFormError.invalidCredentials.localizationKey, "signIn.error.credentials")
        XCTAssertEqual(SignInFormError.network.localizationKey, "signIn.error.service")
        XCTAssertEqual(SignInFormError.serviceUnavailable.localizationKey, "signIn.error.service")
        XCTAssertEqual(SignInFormError.notConfigured.localizationKey, "signIn.error.service")
    }
}
