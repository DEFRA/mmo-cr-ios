import XCTest
@testable import record_catch

@MainActor
final class CreateNewPasswordViewModelTests: XCTestCase {

    private func makeSut(resetter: (any PasswordResetting)? = nil, router: PasswordResetRouter? = nil) -> CreateNewPasswordViewModel {
        CreateNewPasswordViewModel(resetter: resetter ?? FakePasswordResetter(), router: router ?? PasswordResetRouter())
    }

    func test_initialState_hasNoErrors() {
        let sut = makeSut()
        XCTAssertNil(sut.newPasswordFieldError)
        XCTAssertNil(sut.confirmPasswordFieldError)
        XCTAssertNil(sut.formError)
        XCTAssertFalse(sut.isSubmitting)
    }

    // MARK: - AC13/AC15: requirements and blank fields

    func test_submit_whenBothFieldsBlank_setsFieldErrors_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)

        await sut.submit()

        XCTAssertEqual(sut.newPasswordFieldError, .emptyPassword)
        XCTAssertEqual(sut.confirmPasswordFieldError, .empty)
        XCTAssertEqual(resetter.submitNewPasswordCallCount, 0)
    }

    func test_submit_whenPasswordDoesNotMeetRequirements_setsFieldError_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "password"
        sut.confirmPassword = "password"

        await sut.submit()

        XCTAssertEqual(sut.newPasswordFieldError, .notEnoughCharacterClasses)
        XCTAssertEqual(resetter.submitNewPasswordCallCount, 0)
    }

    // MARK: - AC14: mismatch

    func test_submit_whenPasswordsMismatch_setsMismatchError_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)
        let candidatePassword = "TestPassword123!"
        sut.newPassword = candidatePassword
        sut.confirmPassword = candidatePassword.reversed().description // deliberately does not match

        await sut.submit()

        XCTAssertEqual(sut.confirmPasswordFieldError, .mismatch)
        XCTAssertEqual(resetter.submitNewPasswordCallCount, 0)
    }

    // MARK: - AC16: success

    func test_submit_whenValidAndCompleted_pushesCompleteRoute_andClearsBothFields() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .completed)
        let router = PasswordResetRouter()
        router.start()
        let sut = makeSut(resetter: resetter, router: router)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertNil(sut.formError)
        XCTAssertEqual(router.path, [.resetPassword(attempt: 1), .complete])
        XCTAssertEqual(sut.newPassword, "")
        XCTAssertEqual(sut.confirmPassword, "")
        XCTAssertEqual(resetter.lastSubmittedPassword, "TestPassword123!")
    }

    func test_submit_whenDoesNotMeetPolicy_setsFormError_andClearsBothFields() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .doesNotMeetPolicy)
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertEqual(sut.formError, .doesNotMeetPolicy)
        XCTAssertEqual(sut.newPassword, "")
        XCTAssertEqual(sut.confirmPassword, "")
    }

    func test_submit_whenSessionExpired_setsSessionExpiredError() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .sessionExpired)
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertEqual(sut.formError, .sessionExpired)
    }

    func test_submit_whenNetworkFailure_setsNetworkError() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .network)
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertEqual(sut.formError, .network)
    }

    func test_submit_whenServiceUnavailable_setsServiceUnavailableError() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .serviceUnavailable)
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertEqual(sut.formError, .serviceUnavailable)
    }

    func test_clearFormError_clearsError() {
        let sut = makeSut()
        sut.clearFormError()
        XCTAssertNil(sut.formError)
    }

    // MARK: - showFormErrorSummary (AC16: summary hidden for the field-level "missing/invalid" case)

    func test_showFormErrorSummary_whenNoFormError_isFalse() {
        let sut = makeSut()
        XCTAssertFalse(sut.showFormErrorSummary)
    }

    func test_showFormErrorSummary_whenMissingOrInvalidFields_isFalse() async {
        let sut = makeSut()
        await sut.submit() // blank fields → .missingOrInvalidFields
        XCTAssertFalse(sut.showFormErrorSummary)
    }

    func test_showFormErrorSummary_whenServiceLevelError_isTrue() async {
        let resetter = FakePasswordResetter(submitNewPasswordOutcome: .network)
        let sut = makeSut(resetter: resetter)
        sut.newPassword = "TestPassword123!"
        sut.confirmPassword = "TestPassword123!"

        await sut.submit()

        XCTAssertTrue(sut.showFormErrorSummary)
    }

    // MARK: - NewPasswordFormError.localizationKey

    func test_newPasswordFormError_localizationKey_mapsEachCase() {
        XCTAssertNil(NewPasswordFormError.missingOrInvalidFields.localizationKey)
        XCTAssertEqual(NewPasswordFormError.doesNotMeetPolicy.localizationKey, "passwordReset.newPassword.error.requirements")
        XCTAssertEqual(NewPasswordFormError.sessionExpired.localizationKey, "passwordReset.error.sessionExpired")
        XCTAssertEqual(NewPasswordFormError.network.localizationKey, "passwordReset.error.service")
        XCTAssertEqual(NewPasswordFormError.serviceUnavailable.localizationKey, "passwordReset.error.service")
    }
}
