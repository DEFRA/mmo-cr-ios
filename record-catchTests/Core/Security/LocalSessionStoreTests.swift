import XCTest
@testable import record_catch

final class LocalSessionStoreTests: XCTestCase {

    private func makeSut() -> KeychainLocalSessionStore {
        KeychainLocalSessionStore(keychain: KeychainStore(service: "test.session.\(UUID().uuidString)"))
    }

    func test_hasLocalSession_isFalse_beforeBeginSession() {
        let sut = makeSut()
        XCTAssertFalse(sut.hasLocalSession())
    }

    func test_beginSession_setsHasLocalSessionTrue() throws {
        let sut = makeSut()
        try sut.beginSession()
        XCTAssertTrue(sut.hasLocalSession())
    }

    func test_endSession_clearsHasLocalSession() throws {
        let sut = makeSut()
        try sut.beginSession()
        try sut.endSession()
        XCTAssertFalse(sut.hasLocalSession())
    }

    func test_beginSession_isIdempotent() throws {
        let sut = makeSut()
        try sut.beginSession()
        try sut.beginSession()
        XCTAssertTrue(sut.hasLocalSession())
    }
}

final class InMemoryLocalSessionStoreTests: XCTestCase {

    func test_defaultsToNoSession() {
        let sut = InMemoryLocalSessionStore()
        XCTAssertFalse(sut.hasLocalSession())
    }

    func test_respectsInitialValue() {
        let sut = InMemoryLocalSessionStore(hasSession: true)
        XCTAssertTrue(sut.hasLocalSession())
    }

    func test_beginSession_setsTrue() throws {
        let sut = InMemoryLocalSessionStore()
        try sut.beginSession()
        XCTAssertTrue(sut.hasLocalSession())
    }

    func test_endSession_setsFalse() throws {
        let sut = InMemoryLocalSessionStore(hasSession: true)
        try sut.endSession()
        XCTAssertFalse(sut.hasLocalSession())
    }
}
