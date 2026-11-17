import XCTest
@testable import record_catch

/// Core business logic — ≥95% coverage target (testing.instructions.md). Pure, so every branch
/// is cheaply exercised.
final class PasswordResetValidationTests: XCTestCase {

    // MARK: - Email (AC2)

    func test_emailError_whenBlank_returnsEmptyEmail() {
        XCTAssertEqual(PasswordResetValidation.emailError(""), .emptyEmail)
        XCTAssertEqual(PasswordResetValidation.emailError("   "), .emptyEmail)
    }

    func test_emailError_whenInvalidFormat_returnsInvalidEmailFormat() {
        XCTAssertEqual(PasswordResetValidation.emailError("not-an-email"), .invalidEmailFormat)
    }

    func test_emailError_whenValid_returnsNil() {
        XCTAssertNil(PasswordResetValidation.emailError("a@b.com"))
    }

    func test_normalisedEmail_trimsAndLowercases() {
        XCTAssertEqual(PasswordResetValidation.normalisedEmail("  A@B.COM  "), "a@b.com")
    }

    // MARK: - Reset code (AC6)

    func test_codeError_whenBlank_returnsEmptyCode() {
        XCTAssertEqual(PasswordResetValidation.codeError(""), .emptyCode)
        XCTAssertEqual(PasswordResetValidation.codeError("  "), .emptyCode)
    }

    func test_codeError_whenPresent_returnsNil() {
        XCTAssertNil(PasswordResetValidation.codeError("12345678"))
    }

    func test_normalisedCode_trimsWhitespaceOnly() {
        XCTAssertEqual(PasswordResetValidation.normalisedCode("  1234  "), "1234")
    }

    // MARK: - New password (AC13)

    func test_newPasswordError_whenEmpty_returnsEmptyPassword() {
        XCTAssertEqual(PasswordResetValidation.newPasswordError(""), .emptyPassword)
    }

    func test_newPasswordError_whenTooShort_returnsTooShort() {
        XCTAssertEqual(PasswordResetValidation.newPasswordError("Ab1!xy7"), .tooShort) // 7 chars
    }

    func test_newPasswordError_whenEightCharsButOnlyTwoClasses_returnsNotEnoughCharacterClasses() {
        XCTAssertEqual(PasswordResetValidation.newPasswordError("password"), .notEnoughCharacterClasses)
    }

    func test_newPasswordError_whenEightCharsWithThreeClasses_returnsNil() {
        XCTAssertNil(PasswordResetValidation.newPasswordError("Passw0rd"))
    }

    func test_newPasswordError_whenTooLong_returnsTooLong() {
        let longPassword = String(repeating: "Aa1!", count: 65) // 260 chars
        XCTAssertEqual(PasswordResetValidation.newPasswordError(longPassword), .tooLong)
    }

    func test_newPasswordError_atExactMinimumLength_isValid() {
        XCTAssertNil(PasswordResetValidation.newPasswordError("TestPassword123!")) // 8 chars, 3 classes
    }

    func test_newPasswordError_atExactMaximumLength_isValid() {
        let password = "Aa1!" + String(repeating: "a", count: 252) // 256 chars total
        XCTAssertNil(PasswordResetValidation.newPasswordError(password))
    }

    func test_characterClassCount_countsAllFourClasses() {
        XCTAssertEqual(PasswordResetValidation.characterClassCount("Aa1!"), 4)
        XCTAssertEqual(PasswordResetValidation.characterClassCount("aaaa"), 1)
        XCTAssertEqual(PasswordResetValidation.characterClassCount(""), 0)
    }

    // MARK: - Confirm new password (AC14/AC15)

    func test_confirmPasswordError_whenEmpty_returnsEmpty() {
        XCTAssertEqual(PasswordResetValidation.confirmPasswordError(newPassword: "TestPassword123!", confirmPassword: ""), .empty)
    }

    func test_confirmPasswordError_whenMismatch_returnsMismatch() {
        let candidatePassword = "TestPassword123!"
        XCTAssertEqual(
            PasswordResetValidation.confirmPasswordError(
                newPassword: candidatePassword,
                confirmPassword: candidatePassword.reversed().description // deliberately does not match
            ),
            .mismatch
        )
    }

    func test_confirmPasswordError_whenMatch_returnsNil() {
        XCTAssertNil(PasswordResetValidation.confirmPasswordError(newPassword: "TestPassword123!", confirmPassword: "TestPassword123!"))
    }

    // MARK: - localizationKey (string mapping consumed by every PasswordReset view)

    func test_resetEmailFieldError_localizationKey_mapsEachCase() {
        XCTAssertEqual(ResetEmailFieldError.emptyEmail.localizationKey, "passwordReset.email.error.empty")
        XCTAssertEqual(ResetEmailFieldError.invalidEmailFormat.localizationKey, "passwordReset.email.error.invalid")
    }

    func test_resetCodeFieldError_localizationKey_mapsEmptyCode() {
        XCTAssertEqual(ResetCodeFieldError.emptyCode.localizationKey, "passwordReset.code.error.empty")
    }

    func test_newPasswordFieldError_localizationKey_mapsEachCase() {
        XCTAssertEqual(NewPasswordFieldError.emptyPassword.localizationKey, "passwordReset.newPassword.error.empty")
        XCTAssertEqual(NewPasswordFieldError.tooShort.localizationKey, "passwordReset.newPassword.error.requirements")
        XCTAssertEqual(NewPasswordFieldError.notEnoughCharacterClasses.localizationKey, "passwordReset.newPassword.error.requirements")
        XCTAssertEqual(NewPasswordFieldError.tooLong.localizationKey, "passwordReset.newPassword.error.tooLong")
    }

    func test_confirmPasswordFieldError_localizationKey_mapsEachCase() {
        XCTAssertEqual(ConfirmPasswordFieldError.empty.localizationKey, "passwordReset.confirmPassword.error.empty")
        XCTAssertEqual(ConfirmPasswordFieldError.mismatch.localizationKey, "passwordReset.confirmPassword.error.mismatch")
    }
}
