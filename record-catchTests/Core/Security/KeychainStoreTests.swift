import XCTest
@testable import record_catch

final class KeychainStoreTests: XCTestCase {

    /// A dedicated service namespace per test avoids cross-test/cross-run collisions in the
    /// real Keychain (simulator-backed but real `SecItem` calls).
    private func makeSut() -> KeychainStore {
        KeychainStore(service: "test.keychain.\(UUID().uuidString)")
    }

    func test_setAndData_roundTripsPlainItem() throws {
        let sut = makeSut()
        let data = Data("hello".utf8)

        try sut.set(data, account: "account", accessControl: nil)

        XCTAssertEqual(try sut.data(account: "account", prompt: nil), data)
    }

    func test_data_returnsNil_whenNoItemExists() throws {
        let sut = makeSut()
        XCTAssertNil(try sut.data(account: "missing", prompt: nil))
    }

    func test_set_replacesExistingItem() throws {
        let sut = makeSut()
        try sut.set(Data("first".utf8), account: "account", accessControl: nil)
        try sut.set(Data("second".utf8), account: "account", accessControl: nil)

        XCTAssertEqual(try sut.data(account: "account", prompt: nil), Data("second".utf8))
    }

    func test_removeItem_deletesStoredValue() throws {
        let sut = makeSut()
        try sut.set(Data("value".utf8), account: "account", accessControl: nil)

        try sut.removeItem(account: "account")

        XCTAssertNil(try sut.data(account: "account", prompt: nil))
    }

    func test_removeItem_onMissingItem_doesNotThrow() throws {
        let sut = makeSut()
        XCTAssertNoThrow(try sut.removeItem(account: "never-existed"))
    }

    func test_itemExists_isFalse_beforeSet_andTrueAfter() throws {
        let sut = makeSut()
        XCTAssertFalse(sut.itemExists(account: "account"))

        try sut.set(Data("value".utf8), account: "account", accessControl: nil)

        XCTAssertTrue(sut.itemExists(account: "account"))
    }

    func test_itemExists_isFalse_afterRemoval() throws {
        let sut = makeSut()
        try sut.set(Data("value".utf8), account: "account", accessControl: nil)
        try sut.removeItem(account: "account")

        XCTAssertFalse(sut.itemExists(account: "account"))
    }
}

final class InMemoryKeychainStoreTests: XCTestCase {

    func test_setAndData_roundTrips() throws {
        let sut = InMemoryKeychainStore()
        try sut.set(Data("value".utf8), account: "account", accessControl: nil)
        XCTAssertEqual(try sut.data(account: "account", prompt: nil), Data("value".utf8))
    }

    func test_data_returnsNil_forMissingAccount() throws {
        let sut = InMemoryKeychainStore()
        XCTAssertNil(try sut.data(account: "missing", prompt: nil))
    }

    func test_data_throwsInjectedError_whenConfigured() {
        let sut = InMemoryKeychainStore()
        sut.readErrorsByAccount["account"] = BiometricError.authenticationFailed

        XCTAssertThrowsError(try sut.data(account: "account", prompt: nil)) { error in
            XCTAssertEqual(error as? BiometricError, .authenticationFailed)
        }
    }

    func test_removeItem_clearsStoredValue() throws {
        let sut = InMemoryKeychainStore()
        try sut.set(Data("value".utf8), account: "account", accessControl: nil)
        try sut.removeItem(account: "account")
        XCTAssertFalse(sut.itemExists(account: "account"))
    }

    func test_itemExists_reflectsStoredState() throws {
        let sut = InMemoryKeychainStore()
        XCTAssertFalse(sut.itemExists(account: "account"))
        try sut.set(Data(), account: "account", accessControl: nil)
        XCTAssertTrue(sut.itemExists(account: "account"))
    }
}
