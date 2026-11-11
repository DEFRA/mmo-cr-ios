import XCTest
@testable import record_catch

@MainActor
final class ResetPasswordViewModelTests: XCTestCase {

    private func makeSut(resetter: (any PasswordResetting)? = nil, router: PasswordResetRouter? = nil) -> ResetPasswordViewModel {
        ResetPasswordViewModel(resetter: resetter ?? FakePasswordResetter(), router: router ?? PasswordResetRouter())
    }

    func test_initialState_hasNoErrors() {
        let sut = makeSut()
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.formError)
        XCTAssertFalse(sut.isSubmitting)
    }

    func test_submit_whenEmailBlank_setsMissingOrInvalidEmail_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)

        await sut.submit()

        XCTAssertEqual(sut.emailFieldError, .emptyEmail)
        XCTAssertEqual(resetter.requestCodeCallCount, 0)
    }

    func test_submit_whenEmailInvalid_setsInvalidEmailFormat_andDoesNotCallResetter() async {
        let resetter = FakePasswordResetter()
        let sut = makeSut(resetter: resetter)
        sut.email = "not-an-email"

        await sut.submit()

        XCTAssertEqual(sut.emailFieldError, .invalidEmailFormat)
        XCTAssertEqual(resetter.requestCodeCallCount, 0)
    }

    func test_submit_whenValidEmailAndCodeSent_pushesEnterCodeRoute() async {
        let resetter = FakePasswordResetter(requestCodeOutcome: .codeSent)
        let router = PasswordResetRouter()
        let sut = makeSut(resetter: resetter, router: router)
        sut.email = "a@b.com"

        await sut.submit()

        XCTAssertNil(sut.formError)
        XCTAssertEqual(router.path, [.enterCode])
        XCTAssertEqual(resetter.lastRequestedEmail, "a@b.com")
    }

    func test_submit_whenNetworkFailure_setsNetworkError() async {
        let resetter = FakePasswordResetter(requestCodeOutcome: .network)
        let sut = makeSut(resetter: resetter)
        sut.email = "a@b.com"

        await sut.submit()

        XCTAssertEqual(sut.formError, .network)
    }

    func test_submit_whenServiceUnavailable_setsServiceUnavailableError() async {
        let resetter = FakePasswordResetter(requestCodeOutcome: .serviceUnavailable)
        let sut = makeSut(resetter: resetter)
        sut.email = "a@b.com"

        await sut.submit()

        XCTAssertEqual(sut.formError, .serviceUnavailable)
    }

    func test_submit_whenNotConfigured_setsNotConfiguredError() async {
        let resetter = FakePasswordResetter(requestCodeOutcome: .notConfigured)
        let sut = makeSut(resetter: resetter)
        sut.email = "a@b.com"

        await sut.submit()

        XCTAssertEqual(sut.formError, .notConfigured)
    }

    func test_submit_whenAlreadySubmitting_isIgnored() async {
        let resetter = FakePasswordResetter()
        resetter.requestCodeDelayNanoseconds = 50_000_000
        let sut = makeSut(resetter: resetter)
        sut.email = "a@b.com"

        async let first: Void = sut.submit()
        async let second: Void = sut.submit()
        _ = await (first, second)

        XCTAssertEqual(resetter.requestCodeCallCount, 1)
    }

    func test_clearFormError_clearsError() {
        let sut = makeSut()
        sut.email = ""
        Task { await sut.submit() }
        sut.clearFormError()
        XCTAssertNil(sut.formError)
    }
}
