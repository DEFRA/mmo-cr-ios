import XCTest
@testable import record_catch

/// 100% coverage target — this is a security-critical decision path (ADR-0009). Pure and
/// stateless, so every branch is deterministically testable with no I/O.
final class BiometricReentryPolicyTests: XCTestCase {

    // MARK: - offer(hasLocalSession:preferenceEnabled:availability:secretExists:)

    func test_offer_whenNoLocalSession_fallsToSignIn() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: false,
            preferenceEnabled: true,
            availability: .available(.faceID),
            secretExists: true
        )
        XCTAssertEqual(result, .fallToSignIn(.noLocalSession))
    }

    func test_offer_whenPreferenceDisabled_fallsToSignIn() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: false,
            availability: .available(.faceID),
            secretExists: true
        )
        XCTAssertEqual(result, .fallToSignIn(.preferenceDisabled))
    }

    func test_offer_whenBiometryUnavailable_fallsToSignIn() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: true,
            availability: .unavailable(.noBiometryEnrolled),
            secretExists: true
        )
        XCTAssertEqual(result, .fallToSignIn(.biometryUnavailable))
    }

    func test_offer_whenSecretNotProvisioned_fallsToSignIn() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: true,
            availability: .available(.faceID),
            secretExists: false
        )
        XCTAssertEqual(result, .fallToSignIn(.secretNotProvisioned))
    }

    func test_offer_whenEverythingEligible_offersReentry() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: true,
            availability: .available(.touchID),
            secretExists: true
        )
        XCTAssertEqual(result, .offer)
    }

    /// Order of checks matters for diagnostics: session check comes first even when other
    /// conditions also fail.
    func test_offer_checksLocalSessionBeforeOtherConditions() {
        let result = BiometricReentryPolicy.offer(
            hasLocalSession: false,
            preferenceEnabled: false,
            availability: .unavailable(.notSupportedOnDevice),
            secretExists: false
        )
        XCTAssertEqual(result, .fallToSignIn(.noLocalSession))
    }

    // MARK: - nextState(afterEvaluation:)

    func test_nextState_onSuccess_unlocks() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .success(()))
        XCTAssertEqual(result, .unlocked)
    }

    func test_nextState_onLockout_fallsToSignIn() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.biometryLockedOut))
        XCTAssertEqual(result, .fallToSignIn(message: .biometryLockedOut))
    }

    func test_nextState_onBiometryNotAvailable_fallsToSignIn() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.biometryNotAvailable))
        XCTAssertEqual(result, .fallToSignIn(message: .biometryUnavailable))
    }

    func test_nextState_onBiometryNotEnrolled_fallsToSignIn() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.biometryNotEnrolled))
        XCTAssertEqual(result, .fallToSignIn(message: .biometryUnavailable))
    }

    func test_nextState_onPasscodeNotSet_fallsToSignIn() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.passcodeNotSet))
        XCTAssertEqual(result, .fallToSignIn(message: .biometryUnavailable))
    }

    func test_nextState_onUserCancelled_retries() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.userCancelled))
        XCTAssertEqual(result, .retry(message: .cancelled))
    }

    func test_nextState_onSystemCancelled_retries() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.systemCancelled))
        XCTAssertEqual(result, .retry(message: .cancelled))
    }

    func test_nextState_onUserFallback_retries() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.userFallback))
        XCTAssertEqual(result, .retry(message: .cancelled))
    }

    func test_nextState_onAuthenticationFailed_retries() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.authenticationFailed))
        XCTAssertEqual(result, .retry(message: .authenticationFailed))
    }

    func test_nextState_onOtherBiometricError_retries() {
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(BiometricError.other))
        XCTAssertEqual(result, .retry(message: .authenticationFailed))
    }

    func test_nextState_onNonBiometricError_retriesWithGenericMessage() {
        struct SomeOtherError: Error {}
        let result = BiometricReentryPolicy.nextState(afterEvaluation: .failure(SomeOtherError()))
        XCTAssertEqual(result, .retry(message: .authenticationFailed))
    }
}
