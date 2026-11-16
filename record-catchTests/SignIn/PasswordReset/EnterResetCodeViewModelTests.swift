import XCTest
@testable import record_catch

@MainActor
final class EnterResetCodeViewModelTests: XCTestCase {

    private func makeSut(resetter: (any PasswordResetting)? = nil, router: PasswordResetRouter? = nil) -> EnterResetCodeViewModel {
        EnterResetCodeViewModel(resetter: resetter ?? FakePasswordResetter(), router: router ?? PasswordResetRouter())
    }

    func test_initialState_hasNoErrors() {
        let sut = makeSut()
        XCTAssertNil(sut.codeFieldError)
        XCTAssertNil(sut.formError)
        XCTAssertFalse(sut.isSubmitting)
    }

    func test_submit_whenCodeBlank_setsMissingCode_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)

        await sut.submit()

        XCTAssertEqual(sut.codeFieldError, .emptyCode)
        XCTAssertEqual(resetter.verifyCodeCallCount, 0)
    }

    func test_submit_whenCodeVerified_pushesCreatePasswordRoute() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .verified)
        let router = PasswordResetRouter()
        router.start()
        let sut = makeSut(resetter: resetter, router: router)
        sut.code = "12345678"

        await sut.submit()

        XCTAssertNil(sut.formError)
        XCTAssertEqual(router.path, [.resetPassword(attempt: 1), .createPassword])
        XCTAssertEqual(resetter.lastVerifiedCode, "12345678")
    }

    func test_submit_whenInvalidCode_setsInvalidCodeError_andStaysOnScreen() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .invalidCode)
        let router = PasswordResetRouter()
        router.start()
        let sut = makeSut(resetter: resetter, router: router)
        sut.code = "00000000"

        await sut.submit()

        XCTAssertEqual(sut.formError, .invalidCode)
        XCTAssertEqual(router.path, [.resetPassword(attempt: 1)])
    }

    func test_submit_whenExpiredCode_setsExpiredCodeError() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .expired)
        let sut = makeSut(resetter: resetter)
        sut.code = "00000000"

        await sut.submit()

        XCTAssertEqual(sut.formError, .expiredCode)
    }

    func test_submit_whenNetworkFailure_setsNetworkError() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .network)
        let sut = makeSut(resetter: resetter)
        sut.code = "00000000"

        await sut.submit()

        XCTAssertEqual(sut.formError, .network)
    }

    func test_submit_whenServiceUnavailable_setsServiceUnavailableError() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .serviceUnavailable)
        let sut = makeSut(resetter: resetter)
        sut.code = "00000000"

        await sut.submit()

        XCTAssertEqual(sut.formError, .serviceUnavailable)
    }

    // MARK: - "Send a new code" (AC9)

    func test_requestNewCode_cancelsResetterState_andRestartsRouter() {
        let resetter = FakePasswordResetter()
        let router = PasswordResetRouter()
        router.start()
        router.push(.enterCode)
        let sut = makeSut(resetter: resetter, router: router)

        sut.requestNewCode()

        XCTAssertEqual(resetter.cancelCallCount, 1)
        XCTAssertEqual(router.path, [.resetPassword(attempt: 2)])
    }

    func test_clearFormError_clearsError() {
        let sut = makeSut()
        sut.clearFormError()
        XCTAssertNil(sut.formError)
    }

    // MARK: - showSendNewCode (AC8: always offered, see doc comment on the property)

    func test_showSendNewCode_isAlwaysTrue() {
        XCTAssertTrue(makeSut().showSendNewCode)
    }

    // MARK: - showFormErrorSummary (AC6: summary hidden for the field-level "missing code" case)

    func test_showFormErrorSummary_whenNoFormError_isFalse() {
        XCTAssertFalse(makeSut().showFormErrorSummary)
    }

    func test_showFormErrorSummary_whenMissingCode_isFalse() async {
        let sut = makeSut()
        await sut.submit() // blank code → .missingCode
        XCTAssertFalse(sut.showFormErrorSummary)
    }

    func test_showFormErrorSummary_whenServiceLevelError_isTrue() async {
        let resetter = FakePasswordResetter(verifyCodeOutcome: .network)
        let sut = makeSut(resetter: resetter)
        sut.code = "00000000"

        await sut.submit()

        XCTAssertTrue(sut.showFormErrorSummary)
    }

    // MARK: - ResetCodeFormError.localizationKey

    func test_resetCodeFormError_localizationKey_mapsEachCase() {
        XCTAssertNil(ResetCodeFormError.missingCode.localizationKey)
        XCTAssertEqual(ResetCodeFormError.invalidCode.localizationKey, "passwordReset.code.error.invalid")
        XCTAssertEqual(ResetCodeFormError.expiredCode.localizationKey, "passwordReset.code.error.expired")
        XCTAssertEqual(ResetCodeFormError.network.localizationKey, "passwordReset.error.service")
        XCTAssertEqual(ResetCodeFormError.serviceUnavailable.localizationKey, "passwordReset.error.service")
    }
}
