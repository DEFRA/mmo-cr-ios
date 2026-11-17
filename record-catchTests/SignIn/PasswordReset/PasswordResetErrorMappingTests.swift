import XCTest
@testable import record_catch

/// Security-critical path — 100% coverage target (testing.instructions.md). Verifies that every
/// account-existence-revealing failure collapses to the same outcome a real account would get
/// (ADR-0027 §3), and that the expiry/invalid-code/invalid-password classification is correct.
final class PasswordResetErrorMappingTests: XCTestCase {

    // MARK: - requestCodeOutcome (AC3, ADR-0027 §3)

    func test_requestCodeOutcome_whenUserNotFound_returnsCodeSent() {
        let error = ResetErrorInfo(isUserNotFound: true)
        XCTAssertEqual(PasswordResetErrorMapping.requestCodeOutcome(for: error), .codeSent)
    }

    func test_requestCodeOutcome_whenInvalidUsername_returnsCodeSent() {
        let error = ResetErrorInfo(isInvalidUsername: true)
        XCTAssertEqual(PasswordResetErrorMapping.requestCodeOutcome(for: error), .codeSent)
    }

    func test_requestCodeOutcome_whenUserDoesNotHavePassword_returnsCodeSent() {
        let error = ResetErrorInfo(isUserDoesNotHavePassword: true)
        XCTAssertEqual(PasswordResetErrorMapping.requestCodeOutcome(for: error), .codeSent)
    }

    func test_requestCodeOutcome_whenBrowserRequired_returnsServiceUnavailable() {
        let error = ResetErrorInfo(isBrowserRequired: true)
        XCTAssertEqual(PasswordResetErrorMapping.requestCodeOutcome(for: error), .serviceUnavailable)
    }

    func test_requestCodeOutcome_whenGeneralFailure_returnsServiceUnavailable() {
        let error = ResetErrorInfo(errorCodes: [12345])
        XCTAssertEqual(PasswordResetErrorMapping.requestCodeOutcome(for: error), .serviceUnavailable)
    }

    // MARK: - verifyCodeOutcome (AC7/AC8/AC10, ADR-0027 §5)

    func test_verifyCodeOutcome_whenBrowserRequired_returnsServiceUnavailable() {
        let error = ResetErrorInfo(isBrowserRequired: true)
        XCTAssertEqual(PasswordResetErrorMapping.verifyCodeOutcome(for: error, requestedAt: .now), .serviceUnavailable)
    }

    func test_verifyCodeOutcome_whenExpiredTokenErrorCode_returnsExpired() {
        let error = ResetErrorInfo(isInvalidCode: true, errorCodes: [552_003])
        XCTAssertEqual(PasswordResetErrorMapping.verifyCodeOutcome(for: error, requestedAt: .now), .expired)
    }

    func test_verifyCodeOutcome_whenInvalidCodeAndRecentlyRequested_returnsInvalidCode() {
        let error = ResetErrorInfo(isInvalidCode: true)
        let now = Date()
        let requestedAt = now.addingTimeInterval(-10)
        XCTAssertEqual(PasswordResetErrorMapping.verifyCodeOutcome(for: error, requestedAt: requestedAt, now: now), .invalidCode)
    }

    func test_verifyCodeOutcome_whenInvalidCodeButLocalLifetimeElapsed_returnsExpired() {
        let error = ResetErrorInfo(isInvalidCode: true)
        let now = Date()
        let requestedAt = now.addingTimeInterval(-PasswordResetConfiguration.codeLifetime - 1)
        XCTAssertEqual(PasswordResetErrorMapping.verifyCodeOutcome(for: error, requestedAt: requestedAt, now: now), .expired)
    }

    func test_verifyCodeOutcome_whenGeneralFailure_returnsServiceUnavailable() {
        let error = ResetErrorInfo(errorCodes: [999])
        XCTAssertEqual(PasswordResetErrorMapping.verifyCodeOutcome(for: error, requestedAt: .now), .serviceUnavailable)
    }

    // MARK: - submitPasswordOutcome (AC13/AC16)

    func test_submitPasswordOutcome_whenBrowserRequired_returnsServiceUnavailable() {
        let error = ResetErrorInfo(isBrowserRequired: true)
        XCTAssertEqual(PasswordResetErrorMapping.submitPasswordOutcome(for: error), .serviceUnavailable)
    }

    func test_submitPasswordOutcome_whenExpiredToken_returnsSessionExpired() {
        let error = ResetErrorInfo(errorCodes: [552_003])
        XCTAssertEqual(PasswordResetErrorMapping.submitPasswordOutcome(for: error), .sessionExpired)
    }

    func test_submitPasswordOutcome_whenInvalidPassword_returnsDoesNotMeetPolicy() {
        let error = ResetErrorInfo(isInvalidPassword: true)
        XCTAssertEqual(PasswordResetErrorMapping.submitPasswordOutcome(for: error), .doesNotMeetPolicy)
    }

    func test_submitPasswordOutcome_whenGeneralFailure_returnsServiceUnavailable() {
        let error = ResetErrorInfo(errorCodes: [1])
        XCTAssertEqual(PasswordResetErrorMapping.submitPasswordOutcome(for: error), .serviceUnavailable)
    }

    // MARK: - ResetErrorInfo.isExpiredToken

    func test_isExpiredToken_isFalse_whenNoMatchingCode() {
        XCTAssertFalse(ResetErrorInfo(errorCodes: [1, 2, 3]).isExpiredToken)
    }

    func test_isExpiredToken_isTrue_whenMatchingCode() {
        XCTAssertTrue(ResetErrorInfo(errorCodes: [70_002]).isExpiredToken)
    }
}
