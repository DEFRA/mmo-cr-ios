import LocalAuthentication
import XCTest
@testable import record_catch

/// `LABiometricAuthenticator` (the real `LAContext`-backed implementation) is **not**
/// unit-tested here — real biometric hardware isn't available in CI/the simulator (ADR-0009).
/// Business logic depending on biometric evaluation is exercised through
/// `FakeBiometricAuthenticator` below.
final class FakeBiometricAuthenticatorTests: XCTestCase {

    func test_biometricAvailability_returnsConfiguredValue() {
        let sut = FakeBiometricAuthenticator(availability: .available(.faceID))
        XCTAssertEqual(sut.biometricAvailability(), .available(.faceID))
    }

    func test_setAvailability_updatesSubsequentReads() {
        let sut = FakeBiometricAuthenticator(availability: .available(.faceID))
        sut.setAvailability(.unavailable(.biometryLockedOut))
        XCTAssertEqual(sut.biometricAvailability(), .unavailable(.biometryLockedOut))
    }

    func test_authenticate_succeeds_byDefault() async throws {
        let sut = FakeBiometricAuthenticator()
        try await sut.authenticate(reason: "test")
        XCTAssertEqual(sut.authenticateCallCount, 1)
    }

    func test_authenticate_throwsConfiguredError() async {
        let sut = FakeBiometricAuthenticator(authenticateResult: .failure(.authenticationFailed))
        do {
            try await sut.authenticate(reason: "test")
            XCTFail("Expected authenticate to throw")
        } catch {
            XCTAssertEqual(error as? BiometricError, .authenticationFailed)
        }
    }

    func test_setAuthenticateResult_changesSubsequentBehaviour() async {
        let sut = FakeBiometricAuthenticator(authenticateResult: .success(()))
        sut.setAuthenticateResult(.failure(.biometryLockedOut))

        do {
            try await sut.authenticate(reason: "test")
            XCTFail("Expected authenticate to throw")
        } catch {
            XCTAssertEqual(error as? BiometricError, .biometryLockedOut)
        }
    }

    func test_authenticateCallCount_incrementsPerCall() async throws {
        let sut = FakeBiometricAuthenticator()
        try await sut.authenticate(reason: "test")
        try await sut.authenticate(reason: "test")
        XCTAssertEqual(sut.authenticateCallCount, 2)
    }
}

/// Covers the `LABiometryType`/`LAError` → domain-type mapping extensions with fabricated
/// `NSError`s, since a real `LAContext` can't be driven deterministically in CI.
final class BiometricErrorMappingTests: XCTestCase {

    func test_biometryKind_mapsNone() {
        XCTAssertEqual(BiometryKind(.none), .none)
    }

    func test_biometryKind_mapsTouchID() {
        XCTAssertEqual(BiometryKind(.touchID), .touchID)
    }

    func test_biometryKind_mapsFaceID() {
        XCTAssertEqual(BiometryKind(.faceID), .faceID)
    }

    func test_biometryKind_mapsOpticID() {
        XCTAssertEqual(BiometryKind(.opticID), .opticID)
    }

    func test_biometricUnavailableReason_mapsNonLAErrorToOther() {
        let error = NSError(domain: "SomeOtherDomain", code: 1)
        XCTAssertEqual(BiometricUnavailableReason(error), .other)
    }

    func test_biometricUnavailableReason_mapsNilToOther() {
        XCTAssertEqual(BiometricUnavailableReason(nil), .other)
    }

    func test_biometricUnavailableReason_mapsLAErrorCodes() {
        XCTAssertEqual(BiometricUnavailableReason(Self.laNSError(.biometryNotEnrolled)), .noBiometryEnrolled)
        XCTAssertEqual(BiometricUnavailableReason(Self.laNSError(.biometryLockout)), .biometryLockedOut)
        XCTAssertEqual(BiometricUnavailableReason(Self.laNSError(.passcodeNotSet)), .passcodeNotSet)
        XCTAssertEqual(BiometricUnavailableReason(Self.laNSError(.biometryNotAvailable)), .notSupportedOnDevice)
        XCTAssertEqual(BiometricUnavailableReason(Self.laNSError(.invalidContext)), .other)
    }

    func test_biometricError_mapsFromLAErrorCodes() {
        XCTAssertEqual(BiometricError(Self.laError(.userCancel)), .userCancelled)
        XCTAssertEqual(BiometricError(Self.laError(.userFallback)), .userFallback)
        XCTAssertEqual(BiometricError(Self.laError(.systemCancel)), .systemCancelled)
        XCTAssertEqual(BiometricError(Self.laError(.appCancel)), .systemCancelled)
        XCTAssertEqual(BiometricError(Self.laError(.biometryNotAvailable)), .biometryNotAvailable)
        XCTAssertEqual(BiometricError(Self.laError(.biometryNotEnrolled)), .biometryNotEnrolled)
        XCTAssertEqual(BiometricError(Self.laError(.biometryLockout)), .biometryLockedOut)
        XCTAssertEqual(BiometricError(Self.laError(.authenticationFailed)), .authenticationFailed)
        XCTAssertEqual(BiometricError(Self.laError(.passcodeNotSet)), .passcodeNotSet)
        XCTAssertEqual(BiometricError(Self.laError(.invalidContext)), .other)
    }

    /// Fabricates a real `LAError` for a given code — a real `LAContext` can't be driven
    /// deterministically in CI, but `LAError` bridges cleanly from a plain `NSError` in its own
    /// domain, so this exercises the actual `LAError`-mapping switch statements.
    private static func laError(_ code: LAError.Code) -> LAError {
        laNSError(code) as! LAError
    }

    private static func laNSError(_ code: LAError.Code) -> NSError {
        NSError(domain: LAError.errorDomain, code: code.rawValue)
    }
}
