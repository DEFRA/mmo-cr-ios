import XCTest
@testable import record_catch

/// `FakeAuthenticator` is used as a test double throughout the suite, but its own documented
/// behaviour (call counts, the artificial sign-in delay, and `hasCachedAccount` bookkeeping) is
/// exercised directly here rather than only incidentally via other tests.
@MainActor
final class FakeAuthenticatorTests: XCTestCase {

    func test_signIn_onSuccess_setsHasCachedAccount_andIncrementsCallCount() async {
        let account = AuthenticatedAccount(username: "angler@example.com", identifier: "id-1")
        let sut = FakeAuthenticator(signInOutcome: .success(account))

        let outcome = await sut.signIn(email: "angler@example.com", password: "password")

        XCTAssertEqual(outcome, .success(account))
        XCTAssertTrue(sut.hasCachedAccount)
        XCTAssertEqual(sut.signInCallCount, 1)
    }

    func test_signIn_onFailure_doesNotSetHasCachedAccount() async {
        let sut = FakeAuthenticator(signInOutcome: .invalidCredentials)

        let outcome = await sut.signIn(email: "angler@example.com", password: "password")

        XCTAssertEqual(outcome, .invalidCredentials)
        XCTAssertFalse(sut.hasCachedAccount)
    }

    func test_signIn_calledTwice_incrementsCallCountEachTime() async {
        let sut = FakeAuthenticator()
        _ = await sut.signIn(email: "a@example.com", password: "p")
        _ = await sut.signIn(email: "a@example.com", password: "p")

        XCTAssertEqual(sut.signInCallCount, 2)
    }

    func test_signIn_respectsConfiguredDelay() async {
        let sut = FakeAuthenticator(signInDelayNanoseconds: 1)
        _ = await sut.signIn(email: "a@example.com", password: "p")
        XCTAssertEqual(sut.signInCallCount, 1)
    }

    func test_restoreSession_returnsConfiguredOutcome() async {
        let sut = FakeAuthenticator(restoreSessionOutcome: .reauthenticationRequired)
        let outcome = await sut.restoreSession()
        XCTAssertEqual(outcome, .reauthenticationRequired)
    }

    func test_signOut_clearsHasCachedAccount_andIncrementsCallCount() async {
        let sut = FakeAuthenticator(hasCachedAccount: true)
        await sut.signOut()

        XCTAssertFalse(sut.hasCachedAccount)
        XCTAssertEqual(sut.signOutCallCount, 1)
    }

    func test_respectsInitialHasCachedAccount() {
        let sut = FakeAuthenticator(hasCachedAccount: true)
        XCTAssertTrue(sut.hasCachedAccount)
    }
}

/// `UITestStubAuthenticator` (reached via `FakeAuthenticator.makeUITestStub()`) derives its
/// `signIn` outcome from the entered email, per its own documented reserved addresses — this is
/// the `-uiTestAuthStub` seam used by `SignInUITests` (ADR-0022 §10).
@MainActor
final class UITestStubAuthenticatorTests: XCTestCase {

    func test_invalidCredentialsEmail_returnsInvalidCredentials() async {
        let sut = FakeAuthenticator.makeUITestStub()
        let outcome = await sut.signIn(email: "invalid@example.com", password: "anything")
        XCTAssertEqual(outcome, .invalidCredentials)
        XCTAssertFalse(sut.hasCachedAccount)
    }

    func test_offlineEmail_returnsNetwork() async {
        let sut = FakeAuthenticator.makeUITestStub()
        let outcome = await sut.signIn(email: "offline@example.com", password: "anything")
        XCTAssertEqual(outcome, .network)
        XCTAssertFalse(sut.hasCachedAccount)
    }

    func test_slowEmail_eventuallySucceeds() async {
        let sut = FakeAuthenticator.makeUITestStub()
        let outcome = await sut.signIn(email: "slow@example.com", password: "anything")

        guard case .success(let account) = outcome else {
            return XCTFail("Expected .success, got \(outcome)")
        }
        XCTAssertEqual(account.username, "slow@example.com")
        XCTAssertTrue(sut.hasCachedAccount)
    }

    func test_anyOtherEmail_succeedsImmediately() async {
        let sut = FakeAuthenticator.makeUITestStub()
        let outcome = await sut.signIn(email: "someone@example.com", password: "anything")

        guard case .success(let account) = outcome else {
            return XCTFail("Expected .success, got \(outcome)")
        }
        XCTAssertEqual(account.username, "someone@example.com")
        XCTAssertTrue(sut.hasCachedAccount)
    }

    func test_restoreSession_alwaysReportsNoAccount() async {
        let sut = FakeAuthenticator.makeUITestStub()
        let outcome = await sut.restoreSession()
        XCTAssertEqual(outcome, .noAccount)
    }

    func test_signOut_clearsHasCachedAccount() async {
        let sut = FakeAuthenticator.makeUITestStub()
        _ = await sut.signIn(email: "someone@example.com", password: "anything")
        XCTAssertTrue(sut.hasCachedAccount)

        await sut.signOut()

        XCTAssertFalse(sut.hasCachedAccount)
    }
}
