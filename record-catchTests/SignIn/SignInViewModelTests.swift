import XCTest
@testable import record_catch

@MainActor
final class SignInViewModelTests: XCTestCase {

    func test_initialState_hasNoErrors() {
        let sut = SignInViewModel()
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
        XCTAssertFalse(sut.showInvalidCredentials)
    }

    func test_submit_whenPasswordEmpty_setsEmptyPasswordError() {
        let sut = SignInViewModel()
        sut.email = "a@b.com"

        sut.submit()

        XCTAssertEqual(sut.passwordFieldError, .emptyPassword)
        XCTAssertNil(sut.emailFieldError)
    }

    func test_submit_whenBothEmpty_setsBothErrors_andNoCredentialError() {
        let sut = SignInViewModel()

        sut.submit()

        XCTAssertEqual(sut.emailFieldError, .emptyEmail)
        XCTAssertEqual(sut.passwordFieldError, .emptyPassword)
        XCTAssertFalse(sut.showInvalidCredentials)
    }

    func test_submit_whenFieldsPresentAndStubbed_surfacesCredentialError() {
        let sut = SignInViewModel(stubInvalidCredentials: true)
        sut.email = "a@b.com"
        sut.password = "wrong"

        sut.submit()

        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
        XCTAssertTrue(sut.showInvalidCredentials)
    }

    func test_submit_whenFieldsPresentAndStubDisabled_noCredentialError() {
        let sut = SignInViewModel(stubInvalidCredentials: false)
        sut.email = "a@b.com"
        sut.password = "pw"

        sut.submit()

        XCTAssertFalse(sut.showInvalidCredentials)
    }

    func test_fieldErrors_notShownBeforeSubmit() {
        let sut = SignInViewModel()
        // Empty fields, but no submit attempted yet.
        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
    }

    func test_clearCredentialError_resetsFlag() {
        let sut = SignInViewModel(stubInvalidCredentials: true)
        sut.email = "a@b.com"
        sut.password = "pw"
        sut.submit()
        XCTAssertTrue(sut.showInvalidCredentials)

        sut.clearCredentialError()

        XCTAssertFalse(sut.showInvalidCredentials)
    }

    func test_errorClears_whenValidInputProvidedAfterFailedSubmit() {
        let sut = SignInViewModel()
        sut.submit()
        XCTAssertEqual(sut.emailFieldError, .emptyEmail)

        sut.email = "a@b.com"
        sut.password = "pw"

        XCTAssertNil(sut.emailFieldError)
        XCTAssertNil(sut.passwordFieldError)
    }
}
