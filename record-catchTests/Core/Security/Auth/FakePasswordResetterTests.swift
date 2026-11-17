import XCTest
@testable import record_catch

/// `FakePasswordResetter` is used as a test double throughout the password-reset suite, but its
/// own documented behaviour (call counts, last-seen arguments, the artificial delay) is exercised
/// directly here rather than only incidentally via other tests — mirrors `FakeAuthenticatorTests`.
///
/// `UITestStubPasswordResetter` backs the `-uiTestAuthStub` seam (ADR-0027 §2/ADR-0022 §10): unlike
/// `MSALNativePasswordResetter` it has no MSAL dependency, so its deterministic email/code/password
/// branching is fully unit-testable and is asserted here rather than only via XCUITest.
@MainActor
final class FakePasswordResetterTests: XCTestCase {

    // MARK: - FakePasswordResetter

    func test_requestCode_incrementsCallCount_andRecordsLastEmail() async {
        let sut = FakePasswordResetter()
        _ = await sut.requestCode(email: "angler@example.com")
        XCTAssertEqual(sut.requestCodeCallCount, 1)
        XCTAssertEqual(sut.lastRequestedEmail, "angler@example.com")
    }

    func test_requestCode_returnsConfiguredOutcome() async {
        let sut = FakePasswordResetter(requestCodeOutcome: .network)
        let outcome = await sut.requestCode(email: "angler@example.com")
        XCTAssertEqual(outcome, .network)
    }

    func test_requestCode_respectsConfiguredDelay() async {
        let sut = FakePasswordResetter()
        sut.requestCodeDelayNanoseconds = 1
        _ = await sut.requestCode(email: "a@b.com")
        XCTAssertEqual(sut.requestCodeCallCount, 1)
    }

    func test_verifyCode_incrementsCallCount_andRecordsLastCode_andReturnsOutcome() async {
        let sut = FakePasswordResetter(verifyCodeOutcome: .invalidCode)
        let outcome = await sut.verifyCode("12345678")
        XCTAssertEqual(sut.verifyCodeCallCount, 1)
        XCTAssertEqual(sut.lastVerifiedCode, "12345678")
        XCTAssertEqual(outcome, .invalidCode)
    }

    func test_submitNewPassword_incrementsCallCount_andRecordsLastPassword_andReturnsOutcome() async {
        let sut = FakePasswordResetter(submitNewPasswordOutcome: .doesNotMeetPolicy)
        let outcome = await sut.submitNewPassword("TestPassword123!")
        XCTAssertEqual(sut.submitNewPasswordCallCount, 1)
        XCTAssertEqual(sut.lastSubmittedPassword, "TestPassword123!")
        XCTAssertEqual(outcome, .doesNotMeetPolicy)
    }

    func test_cancel_incrementsCallCount() {
        let sut = FakePasswordResetter()
        sut.cancel()
        XCTAssertEqual(sut.cancelCallCount, 1)
    }

    // MARK: - UITestStubPasswordResetter — requestCode (reserved example.com addresses)

    func test_uiTestStub_requestCode_forOfflineEmail_returnsNetwork() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.requestCode(email: "offline@example.com")
        XCTAssertEqual(outcome, .network)
    }

    func test_uiTestStub_requestCode_forErrorEmail_returnsServiceUnavailable() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.requestCode(email: "error@example.com")
        XCTAssertEqual(outcome, .serviceUnavailable)
    }

    func test_uiTestStub_requestCode_forAnyOtherEmail_returnsCodeSent() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.requestCode(email: "angler@example.com")
        XCTAssertEqual(outcome, .codeSent)
    }

    func test_uiTestStub_requestCode_normalisesEmailBeforeMatching() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.requestCode(email: "  OFFLINE@EXAMPLE.COM  ")
        XCTAssertEqual(outcome, .network)
    }

    // MARK: - UITestStubPasswordResetter — verifyCode (reserved codes)

    func test_uiTestStub_verifyCode_forInvalidCode_returnsInvalidCode() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.verifyCode("11111111")
        XCTAssertEqual(outcome, .invalidCode)
    }

    func test_uiTestStub_verifyCode_forExpiredCode_returnsExpired() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.verifyCode("22222222")
        XCTAssertEqual(outcome, .expired)
    }

    func test_uiTestStub_verifyCode_forAnyOtherCode_returnsVerified() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.verifyCode("99999999")
        XCTAssertEqual(outcome, .verified)
    }

    // MARK: - UITestStubPasswordResetter — submitNewPassword / cancel

    func test_uiTestStub_submitNewPassword_forWeakPassword_returnsDoesNotMeetPolicy() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.submitNewPassword("TestWeakPassword1!")
        XCTAssertEqual(outcome, .doesNotMeetPolicy)
    }

    func test_uiTestStub_submitNewPassword_forAnyOtherPassword_returnsCompleted() async {
        let sut = UITestStubPasswordResetter()
        let outcome = await sut.submitNewPassword("TestPassword123!")
        XCTAssertEqual(outcome, .completed)
    }

    func test_uiTestStub_cancel_doesNotThrow() {
        let sut = UITestStubPasswordResetter()
        sut.cancel() // no state to assert — covers the no-op body
    }
}
