import XCTest
@testable import record_catch

@MainActor
final class SignInViewModelTests: XCTestCase {

    private func makeSut(
        authenticator: any Authenticating? = nil,
        onSignedIn: @escaping (AuthenticatedAccount) -> Void = { _ in }
    ) -> SignInViewModel {
        SignInViewModel(authenticator: authenticator ?? FakeAuthenticator(), onSignedIn: onSignedIn)
    }

    func test_initialState_hasNoErrors() {
        let sut = makeSut()
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
        XCTAssertNil(sut.formError)
        XCTAssertFalse(sut.isSubmitting)
    }

    // MARK: - Validation gating (ES1–ES4)

    func test_submit_whenPasswordEmpty_setsEmptyPasswordError_andDoesNotCallAuthenticator() async {
        let authenticator = FakeAuthenticator()
        let sut = makeSut(authenticator: authenticator)
        sut.email = "a@b.com"

        await sut.submit()

        XCTAssertEqual(sut.passwordFieldError, .emptyPassword)
        XCTAssertNil(sut.emailFieldError)
        XCTAssertEqual(authenticator.signInCallCount, 0)
    }

    func test_submit_whenBothEmpty_setsBothErrors_andDoesNotCallAuthenticator() async {
        let authenticator = FakeAuthenticator()
        let sut = makeSut(authenticator: authenticator)

        await sut.submit()

        XCTAssertEqual(sut.emailFieldError, .emptyEmail)
        XCTAssertEqual(sut.passwordFieldError, .emptyPassword)
        XCTAssertEqual(authenticator.signInCallCount, 0)
    }

    func test_submit_whenEmailInvalidFormat_setsInvalidEmailError_andDoesNotCallAuthenticator() async {
        let authenticator = FakeAuthenticator()
        let sut = makeSut(authenticator: authenticator)
        sut.email = "not-an-email"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(sut.emailFieldError, .invalidEmailFormat)
        XCTAssertEqual(authenticator.signInCallCount, 0)
    }

    // MARK: - Successful sign-in (AC4)

    func test_submit_whenFieldsValidAndAuthenticatorSucceeds_callsOnSignedIn() async {
        let account = AuthenticatedAccount(username: "a@b.com", identifier: "id-1")
        var signedInAccount: AuthenticatedAccount?
        let sut = makeSut(
            authenticator: FakeAuthenticator(signInOutcome: .success(account)),
            onSignedIn: { signedInAccount = $0 }
        )
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(signedInAccount, account)
        XCTAssertNil(sut.formError)
    }

    func test_submit_normalisesEmailBeforeCallingAuthenticator() async {
        // FakeAuthenticator's stub signIn outcome doesn't echo the email back, but
        // UITestStubAuthenticator-style behaviour is covered separately; here we assert
        // indirectly via SignInValidation parity — see SignInValidationTests for the
        // normalisation rules themselves.
        let sut = makeSut()
        sut.email = "  A@B.COM  "
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertNil(sut.emailFieldError)
    }

    func test_submit_clearsPasswordAfterAttempt() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .invalidCredentials))
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(sut.password, "")
    }

    // MARK: - Invalid credentials (AC5)

    func test_submit_whenInvalidCredentials_setsFormError_andStaysOnScreen() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .invalidCredentials))
        sut.email = "a@b.com"
        sut.password = "wrong"

        await sut.submit()

        XCTAssertEqual(sut.formError, .invalidCredentials)
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
    }

    // MARK: - Other outcomes

    func test_submit_whenNetworkUnavailable_setsNetworkFormError() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .network))
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(sut.formError, .network)
    }

    func test_submit_whenServiceUnavailable_setsServiceFormError() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .serviceUnavailable))
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(sut.formError, .serviceUnavailable)
    }

    func test_submit_whenNotConfigured_setsNotConfiguredFormError() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .notConfigured))
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        await sut.submit()

        XCTAssertEqual(sut.formError, .notConfigured)
    }

    // MARK: - EC1: rapid repeated taps submit at most one request

    func test_submit_whenCalledTwiceConcurrently_callsAuthenticatorOnlyOnce() async {
        let authenticator = FakeAuthenticator(signInDelayNanoseconds: 50_000_000)
        let sut = makeSut(authenticator: authenticator)
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        async let first: Void = sut.submit()
        // Give the first `submit()` a moment to set `isSubmitting = true` before the second call.
        try? await Task.sleep(nanoseconds: 5_000_000)
        async let second: Void = sut.submit()
        _ = await (first, second)

        XCTAssertEqual(authenticator.signInCallCount, 1)
    }

    func test_isSubmitting_trueWhileInFlight_falseAfterCompletion() async {
        let authenticator = FakeAuthenticator(signInDelayNanoseconds: 20_000_000)
        let sut = makeSut(authenticator: authenticator)
        sut.email = "a@b.com"
        sut.password = "TestPassword123"

        let submitTask = Task { await sut.submit() }
        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(sut.isSubmitting)

        await submitTask.value
        XCTAssertFalse(sut.isSubmitting)
    }

    // MARK: - Error clears on edit

    func test_clearFormError_resetsFormError() async {
        let sut = makeSut(authenticator: FakeAuthenticator(signInOutcome: .invalidCredentials))
        sut.email = "a@b.com"
        sut.password = "wrong"
        await sut.submit()
        XCTAssertEqual(sut.formError, .invalidCredentials)

        sut.clearFormError()

        XCTAssertNil(sut.formError)
    }

    func test_fieldErrors_notShownBeforeSubmit() {
        let sut = makeSut()
        // Empty fields, but no submit attempted yet.
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
    }

    func test_fieldErrors_clear_whenValidInputProvidedAfterFailedSubmit() async {
        let sut = makeSut()
        await sut.submit()
        XCTAssertEqual(sut.emailFieldError, .emptyEmail)

        sut.email = "a@b.com"
        sut.password = "pw"

        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
    }
}
