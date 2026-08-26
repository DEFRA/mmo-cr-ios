import XCTest
@testable import record_catch

/// Security-critical path — 100% coverage target (testing.instructions.md).
@MainActor
final class AppLockViewModelTests: XCTestCase {

    private func makeSut(
        biometricAuthenticator: BiometricAuthenticating = FakeBiometricAuthenticator(),
        sessionStore: LocalSessionStoring = InMemoryLocalSessionStore(hasSession: true),
        secretStore: ReentrySecretStoring = InMemoryReentrySecretStore(exists: true),
        preferenceStore: BiometricPreferenceStoring = InMemoryBiometricPreferenceStore(initialValue: true)
    ) -> AppLockViewModel {
        AppLockViewModel(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore,
            unlockReason: "test reason"
        )
    }

    func test_initialState_isChecking() {
        let sut = makeSut()
        XCTAssertEqual(sut.state, .checking)
    }

    func test_biometryKind_reflectsAuthenticatorAvailability() {
        let sut = makeSut(biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.touchID)))
        XCTAssertEqual(sut.biometryKind, .touchID)
    }

    func test_biometryKind_isNone_whenUnavailable() {
        let sut = makeSut(biometricAuthenticator: FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled)))
        XCTAssertEqual(sut.biometryKind, .none)
    }

    // MARK: - evaluateOffer()

    func test_evaluateOffer_whenEligible_showsLockedWithNoMessage() {
        let sut = makeSut()
        var fallbackCalled = false
        sut.onFallbackToSignIn = { fallbackCalled = true }

        sut.evaluateOffer()

        XCTAssertEqual(sut.state, .locked(message: nil))
        XCTAssertFalse(fallbackCalled)
    }

    func test_evaluateOffer_whenNoLocalSession_fallsBackToSignIn() {
        let sut = makeSut(sessionStore: InMemoryLocalSessionStore(hasSession: false))
        var fallbackCalled = false
        sut.onFallbackToSignIn = { fallbackCalled = true }

        sut.evaluateOffer()

        XCTAssertEqual(sut.state, .fallbackToSignIn)
        XCTAssertTrue(fallbackCalled)
    }

    func test_evaluateOffer_whenPreferenceDisabled_fallsBackToSignIn() {
        let sut = makeSut(preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false))
        sut.evaluateOffer()
        XCTAssertEqual(sut.state, .fallbackToSignIn)
    }

    func test_evaluateOffer_whenBiometryUnavailable_fallsBackToSignIn() {
        let sut = makeSut(biometricAuthenticator: FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled)))
        sut.evaluateOffer()
        XCTAssertEqual(sut.state, .fallbackToSignIn)
    }

    func test_evaluateOffer_whenSecretNotProvisioned_fallsBackToSignIn() {
        let sut = makeSut(secretStore: InMemoryReentrySecretStore(exists: false))
        sut.evaluateOffer()
        XCTAssertEqual(sut.state, .fallbackToSignIn)
    }

    // MARK: - authenticate()

    func test_authenticate_onSuccess_unlocks() async {
        let sut = makeSut(secretStore: InMemoryReentrySecretStore(exists: true))
        var unlockedCalled = false
        sut.onUnlocked = { unlockedCalled = true }

        await sut.authenticate()

        XCTAssertEqual(sut.state, .unlocked)
        XCTAssertTrue(unlockedCalled)
    }

    func test_authenticate_onCancel_retriesWithMessage() async {
        let secretStore = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.userCancelled)
        let sut = makeSut(secretStore: secretStore)

        await sut.authenticate()

        XCTAssertEqual(sut.state, .locked(message: .cancelled))
    }

    func test_authenticate_onAuthenticationFailed_retriesWithMessage() async {
        let secretStore = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.authenticationFailed)
        let sut = makeSut(secretStore: secretStore)

        await sut.authenticate()

        XCTAssertEqual(sut.state, .locked(message: .authenticationFailed))
    }

    func test_authenticate_onLockout_fallsBackToSignIn() async {
        let secretStore = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.biometryLockedOut)
        let sut = makeSut(secretStore: secretStore)
        var fallbackCalled = false
        sut.onFallbackToSignIn = { fallbackCalled = true }

        await sut.authenticate()

        XCTAssertEqual(sut.state, .fallbackToSignIn)
        XCTAssertTrue(fallbackCalled)
    }

    func test_authenticate_onBiometryUnavailable_fallsBackToSignIn() async {
        let secretStore = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.biometryNotAvailable)
        let sut = makeSut(secretStore: secretStore)

        await sut.authenticate()

        XCTAssertEqual(sut.state, .fallbackToSignIn)
    }

    func test_authenticate_retryThenSucceed() async {
        let secretStore = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.authenticationFailed)
        let sut = makeSut(secretStore: secretStore)

        await sut.authenticate()
        XCTAssertEqual(sut.state, .locked(message: .authenticationFailed))

        secretStore.setVerifyError(nil)
        await sut.authenticate()

        XCTAssertEqual(sut.state, .unlocked)
    }

    // MARK: - useSignInInstead()

    func test_useSignInInstead_alwaysAvailable_fallsBackToSignIn() {
        let sut = makeSut()
        var fallbackCalled = false
        sut.onFallbackToSignIn = { fallbackCalled = true }

        sut.useSignInInstead()

        XCTAssertEqual(sut.state, .fallbackToSignIn)
        XCTAssertTrue(fallbackCalled)
    }

    func test_useSignInInstead_worksEvenWhenBiometricsWereAvailable() {
        // Never a dead end: the manual fallback works regardless of biometric eligibility
        // (accessibility.instructions.md).
        let sut = makeSut()
        sut.evaluateOffer()
        XCTAssertEqual(sut.state, .locked(message: nil))

        sut.useSignInInstead()

        XCTAssertEqual(sut.state, .fallbackToSignIn)
    }
}
