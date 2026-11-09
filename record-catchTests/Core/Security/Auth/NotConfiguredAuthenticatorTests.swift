import XCTest
@testable import record_catch

/// `NotConfiguredAuthenticator` (used whenever `EntraConfiguration` placeholders aren't yet
/// populated for a stage — ADR-0022 §6) is pure, MSAL-SDK-free logic, so it's fully unit-tested
/// here. `MSALNativeAuthenticator` itself wraps the real MSAL Native Authentication SDK and talks
/// to a live Entra tenant over the network — it is exercised through manual/device QA (ADR-0022),
/// not unit tests, mirroring the project's existing approach to other hardware/network-bound
/// Keychain and biometric wrappers (see `ReentrySecretStoreTests`'s note on
/// `KeychainReentrySecretStore`).
final class NotConfiguredAuthenticatorTests: XCTestCase {

    @MainActor
    func test_signIn_alwaysReportsNotConfigured() async {
        let sut = NotConfiguredAuthenticator()
        let outcome = await sut.signIn(email: "angler@example.com", password: "password")
        XCTAssertEqual(outcome, .notConfigured)
    }

    @MainActor
    func test_restoreSession_alwaysReportsNoAccount() async {
        let sut = NotConfiguredAuthenticator()
        let outcome = await sut.restoreSession()
        XCTAssertEqual(outcome, .noAccount)
    }

    @MainActor
    func test_signOut_isANoOp() async {
        let sut = NotConfiguredAuthenticator()
        await sut.signOut()
        // No state to assert: signOut is documented as a no-op (see production code comment);
        // this test exists so the call is exercised and the method never silently regresses into
        // a crash/throw.
    }

    @MainActor
    func test_hasCachedAccount_isAlwaysFalse() {
        let sut = NotConfiguredAuthenticator()
        XCTAssertFalse(sut.hasCachedAccount)
    }
}
