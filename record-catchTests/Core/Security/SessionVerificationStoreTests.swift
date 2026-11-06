import XCTest
@testable import record_catch

/// `KeychainSessionVerificationStore`'s business logic (date encoding/decoding and delegating to
/// `KeychainStoring`) is exercised here with an injected `InMemoryKeychainStore` — no real
/// hardware or Keychain entitlement needed (ADR-0022 §4/§5).
final class KeychainSessionVerificationStoreTests: XCTestCase {

    func test_lastVerified_isNil_beforeMarking() {
        let sut = KeychainSessionVerificationStore(keychain: InMemoryKeychainStore())
        XCTAssertNil(sut.lastVerified())
    }

    func test_markVerified_thenLastVerified_returnsSameDate() throws {
        let sut = KeychainSessionVerificationStore(keychain: InMemoryKeychainStore())
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        try sut.markVerified(date)

        XCTAssertEqual(sut.lastVerified(), date)
    }

    func test_markVerified_overwritesPreviousValue() throws {
        let sut = KeychainSessionVerificationStore(keychain: InMemoryKeychainStore())
        try sut.markVerified(Date(timeIntervalSinceReferenceDate: 1_000))

        let newer = Date(timeIntervalSinceReferenceDate: 2_000)
        try sut.markVerified(newer)

        XCTAssertEqual(sut.lastVerified(), newer)
    }

    func test_clear_removesStoredValue() throws {
        let sut = KeychainSessionVerificationStore(keychain: InMemoryKeychainStore())
        try sut.markVerified(.now)

        try sut.clear()

        XCTAssertNil(sut.lastVerified())
    }

    func test_lastVerified_returnsNil_whenKeychainReadThrows() throws {
        let keychain = InMemoryKeychainStore()
        let sut = KeychainSessionVerificationStore(keychain: keychain)
        try sut.markVerified(.now)
        keychain.readErrorsByAccount["auth.lastVerified"] = BiometricError.userCancelled

        XCTAssertNil(sut.lastVerified())
    }

    func test_markVerified_propagatesKeychainWriteError() {
        let keychain = ThrowingOnSetKeychainStore()
        let sut = KeychainSessionVerificationStore(keychain: keychain)

        XCTAssertThrowsError(try sut.markVerified(.now))
    }

    func test_clear_propagatesKeychainRemoveError() {
        let keychain = ThrowingOnRemoveKeychainStore()
        let sut = KeychainSessionVerificationStore(keychain: keychain)

        XCTAssertThrowsError(try sut.clear())
    }
}

/// `InMemorySessionVerificationStore` is a simple, already-exercised (via
/// `RootSessionCoordinatorTests`) in-memory double — covered directly here too so its own
/// behaviour is documented and doesn't silently regress.
final class InMemorySessionVerificationStoreTests: XCTestCase {

    func test_lastVerified_isNil_byDefault() {
        let sut = InMemorySessionVerificationStore()
        XCTAssertNil(sut.lastVerified())
    }

    func test_respectsInitialStoredDate() {
        let date = Date(timeIntervalSinceReferenceDate: 500)
        let sut = InMemorySessionVerificationStore(storedDate: date)
        XCTAssertEqual(sut.lastVerified(), date)
    }

    func test_markVerified_updatesLastVerified() throws {
        let sut = InMemorySessionVerificationStore()
        let date = Date(timeIntervalSinceReferenceDate: 750)

        try sut.markVerified(date)

        XCTAssertEqual(sut.lastVerified(), date)
    }

    func test_clear_removesStoredDate() throws {
        let sut = InMemorySessionVerificationStore(storedDate: .now)

        try sut.clear()

        XCTAssertNil(sut.lastVerified())
    }
}

// MARK: - Test doubles

/// A minimal `KeychainStoring` double whose `set` always throws — isolates
/// `KeychainSessionVerificationStore.markVerified`'s error-propagation path without needing
/// `InMemoryKeychainStore` to grow a write-error seam of its own.
private final class ThrowingOnSetKeychainStore: KeychainStoring, @unchecked Sendable {
    func set(_: Data, account _: String, accessControl _: SecAccessControl?) throws {
        throw BiometricError.other
    }

    func data(account _: String, prompt _: String?) throws -> Data? { nil }

    func removeItem(account _: String) throws {
        // Intentionally empty: never exercised by the tests using this double.
    }

    func itemExists(account _: String) -> Bool { false }
}

/// A minimal `KeychainStoring` double whose `removeItem` always throws — isolates
/// `KeychainSessionVerificationStore.clear`'s error-propagation path.
private final class ThrowingOnRemoveKeychainStore: KeychainStoring, @unchecked Sendable {
    func set(_: Data, account _: String, accessControl _: SecAccessControl?) throws {
        // Intentionally empty: never exercised by the tests using this double.
    }

    func data(account _: String, prompt _: String?) throws -> Data? { nil }

    func removeItem(account _: String) throws {
        throw BiometricError.other
    }

    func itemExists(account _: String) -> Bool { false }
}
