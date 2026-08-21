import XCTest
@testable import record_catch

@MainActor
final class ManageAccountViewModelTests: XCTestCase {

    func test_init_loadsAccount_fromProvider() {
        let account = Account(
            firstName: "Test",
            lastName: "User",
            address: "1 Test Street",
            email: "test@example.com",
            contactNumber: "00000 000000"
        )
        let sut = ManageAccountViewModel(
            accountProvider: StubAccountProvider(account: account),
            biometricStore: InMemoryBiometricPreferenceStore()
        )

        XCTAssertEqual(sut.account, account)
    }

    func test_init_defaultsFaceIDEnabled_fromBiometricStore() {
        let store = InMemoryBiometricPreferenceStore(initialValue: true)
        let sut = ManageAccountViewModel(biometricStore: store)

        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_init_readsExistingDisabledFaceIDPreference() {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let sut = ManageAccountViewModel(biometricStore: store)

        XCTAssertFalse(sut.faceIDEnabled)
    }

    func test_settingFaceIDEnabled_toTrue_persistsToStore() {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let sut = ManageAccountViewModel(biometricStore: store)

        sut.faceIDEnabled = true

        XCTAssertTrue(store.isFaceIDEnabled())
    }

    func test_settingFaceIDEnabled_toFalse_persistsToStore() {
        let store = InMemoryBiometricPreferenceStore(initialValue: true)
        let sut = ManageAccountViewModel(biometricStore: store)

        sut.faceIDEnabled = false

        XCTAssertFalse(store.isFaceIDEnabled())
    }

    func test_settingFaceIDEnabled_toSameValue_doesNotRewriteStore() {
        let store = SpyBiometricPreferenceStore(initialValue: true)
        let sut = ManageAccountViewModel(biometricStore: store)

        sut.faceIDEnabled = true

        XCTAssertEqual(store.setCallCount, 0)
    }

    // MARK: - Inert seams
    //
    // Every seam below is a deliberate no-op in this phase (see ManageAccountViewModel). These
    // tests assert calling them has no observable side effect on unrelated state.

    func test_changeFirstNameTapped_hasNoSideEffects() {
        let sut = ManageAccountViewModel(biometricStore: InMemoryBiometricPreferenceStore(initialValue: true))
        sut.changeFirstNameTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeLastNameTapped_hasNoSideEffects() {
        let sut = ManageAccountViewModel(biometricStore: InMemoryBiometricPreferenceStore(initialValue: true))
        sut.changeLastNameTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeAddressTapped_hasNoSideEffects() {
        let sut = ManageAccountViewModel(biometricStore: InMemoryBiometricPreferenceStore(initialValue: true))
        sut.changeAddressTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeEmailTapped_hasNoSideEffects() {
        let sut = ManageAccountViewModel(biometricStore: InMemoryBiometricPreferenceStore(initialValue: true))
        sut.changeEmailTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeContactNumberTapped_hasNoSideEffects() {
        let sut = ManageAccountViewModel(biometricStore: InMemoryBiometricPreferenceStore(initialValue: true))
        sut.changeContactNumberTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }
}

/// Records how many times `setFaceIDEnabled` is called, so tests can assert the view model
/// skips redundant writes when the value doesn't actually change.
private final class SpyBiometricPreferenceStore: BiometricPreferenceStoring, @unchecked Sendable {
    private(set) var setCallCount = 0
    private var enabled: Bool

    init(initialValue: Bool) {
        self.enabled = initialValue
    }

    func isFaceIDEnabled() -> Bool { enabled }

    func setFaceIDEnabled(_ enabled: Bool) {
        setCallCount += 1
        self.enabled = enabled
    }
}
