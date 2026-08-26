import XCTest
@testable import record_catch

/// `KeychainReentrySecretStore` (the real, `.biometryCurrentSet`-protected implementation) is
/// **not** unit-tested here: provisioning/reading a biometric-gated Keychain item requires a
/// device passcode and real Secure Enclave hardware, neither of which is reliably available in
/// CI/the simulator (see ADR-0009 and testing.instructions.md's note on hardware limits). Its
/// business-logic-facing behaviour is exercised entirely through `InMemoryReentrySecretStore`
/// below, and the ADR requires a real-device manual QA matrix before beta.
final class InMemoryReentrySecretStoreTests: XCTestCase {

    func test_secretExists_isFalse_beforeProvisioning() {
        let sut = InMemoryReentrySecretStore()
        XCTAssertFalse(sut.secretExists())
    }

    func test_respectsInitialExistsValue() {
        let sut = InMemoryReentrySecretStore(exists: true)
        XCTAssertTrue(sut.secretExists())
    }

    func test_provisionSecret_setsExistsTrue() throws {
        let sut = InMemoryReentrySecretStore()
        try sut.provisionSecret()
        XCTAssertTrue(sut.secretExists())
    }

    func test_clearSecret_setsExistsFalse() throws {
        let sut = InMemoryReentrySecretStore(exists: true)
        try sut.clearSecret()
        XCTAssertFalse(sut.secretExists())
    }

    func test_verifyReentry_succeeds_whenProvisionedAndNoErrorConfigured() async throws {
        let sut = InMemoryReentrySecretStore(exists: true)
        try await sut.verifyReentry(reason: "test")
    }

    func test_verifyReentry_throws_whenNotProvisioned() async {
        let sut = InMemoryReentrySecretStore(exists: false)
        do {
            try await sut.verifyReentry(reason: "test")
            XCTFail("Expected verifyReentry to throw")
        } catch {
            XCTAssertEqual(error as? KeychainError, .unexpectedData)
        }
    }

    func test_verifyReentry_throwsInjectedError() async {
        let sut = InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.biometryLockedOut)
        do {
            try await sut.verifyReentry(reason: "test")
            XCTFail("Expected verifyReentry to throw")
        } catch {
            XCTAssertEqual(error as? BiometricError, .biometryLockedOut)
        }
    }

    func test_setVerifyError_changesSubsequentBehaviour() async {
        let sut = InMemoryReentrySecretStore(exists: true)
        sut.setVerifyError(BiometricError.authenticationFailed)

        do {
            try await sut.verifyReentry(reason: "test")
            XCTFail("Expected verifyReentry to throw")
        } catch {
            XCTAssertEqual(error as? BiometricError, .authenticationFailed)
        }

        sut.setVerifyError(nil)
        try? await sut.verifyReentry(reason: "test")
    }
}
