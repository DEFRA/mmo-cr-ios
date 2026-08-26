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
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )

        XCTAssertEqual(sut.account, account)
    }

    func test_init_defaultsFaceIDEnabled_fromBiometricStore() {
        let store = InMemoryBiometricPreferenceStore(initialValue: true)
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )

        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_init_readsExistingDisabledFaceIDPreference() {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )

        XCTAssertFalse(sut.faceIDEnabled)
    }

    func test_init_hasNoEnableFailedMessage() {
        let sut = ManageAccountViewModel(
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )
        XCTAssertFalse(sut.enableFailedMessage)
    }

    // MARK: - enableFaceID() — ADR-0009 §8: requires a live, successful biometric check

    func test_enableFaceID_whenBiometricCheckSucceeds_persistsPreference_andProvisionsSecret() async {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let secretStore = InMemoryReentrySecretStore()
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(authenticateResult: .success(())),
            secretStore: secretStore
        )

        await sut.enableFaceID()

        XCTAssertTrue(sut.faceIDEnabled)
        XCTAssertTrue(store.isFaceIDEnabled())
        XCTAssertTrue(secretStore.secretExists())
        XCTAssertFalse(sut.enableFailedMessage)
    }

    func test_enableFaceID_whenBiometricCheckFails_doesNotPersistPreference_andSurfacesFailure() async {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let secretStore = InMemoryReentrySecretStore()
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(authenticateResult: .failure(.authenticationFailed)),
            secretStore: secretStore
        )

        await sut.enableFaceID()

        XCTAssertFalse(sut.faceIDEnabled)
        XCTAssertFalse(store.isFaceIDEnabled())
        XCTAssertFalse(secretStore.secretExists())
        XCTAssertTrue(sut.enableFailedMessage)
    }

    func test_enableFaceID_whenBiometryUnavailable_doesNotPersistPreference() async {
        let store = InMemoryBiometricPreferenceStore(initialValue: false)
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(
                availability: .unavailable(.noBiometryEnrolled),
                authenticateResult: .failure(.biometryNotEnrolled)
            ),
            secretStore: InMemoryReentrySecretStore()
        )

        await sut.enableFaceID()

        XCTAssertFalse(sut.faceIDEnabled)
        XCTAssertTrue(sut.enableFailedMessage)
    }

    func test_enableFaceID_succeedingAfterAPriorFailure_clearsFailureMessage() async {
        let authenticator = FakeBiometricAuthenticator(authenticateResult: .failure(.authenticationFailed))
        let sut = ManageAccountViewModel(
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: authenticator,
            secretStore: InMemoryReentrySecretStore()
        )
        await sut.enableFaceID()
        XCTAssertTrue(sut.enableFailedMessage)

        authenticator.setAuthenticateResult(.success(()))
        await sut.enableFaceID()

        XCTAssertTrue(sut.faceIDEnabled)
        XCTAssertFalse(sut.enableFailedMessage)
    }

    // MARK: - disableFaceID()

    func test_disableFaceID_persistsPreference_andClearsSecret() async {
        let store = InMemoryBiometricPreferenceStore(initialValue: true)
        let secretStore = InMemoryReentrySecretStore(exists: true)
        let sut = ManageAccountViewModel(
            biometricStore: store,
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: secretStore
        )

        sut.disableFaceID()

        XCTAssertFalse(sut.faceIDEnabled)
        XCTAssertFalse(store.isFaceIDEnabled())
        XCTAssertFalse(secretStore.secretExists())
    }

    func test_disableFaceID_clearsAnyPriorFailureMessage() async {
        let sut = ManageAccountViewModel(
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(authenticateResult: .failure(.authenticationFailed)),
            secretStore: InMemoryReentrySecretStore()
        )
        await sut.enableFaceID()
        XCTAssertTrue(sut.enableFailedMessage)

        sut.disableFaceID()

        XCTAssertFalse(sut.enableFailedMessage)
    }

    // MARK: - Inert seams
    //
    // Every seam below is a deliberate no-op in this phase (see ManageAccountViewModel). These
    // tests assert calling them has no observable side effect on unrelated state.

    private func makeSut(faceIDEnabled: Bool = true) -> ManageAccountViewModel {
        ManageAccountViewModel(
            biometricStore: InMemoryBiometricPreferenceStore(initialValue: faceIDEnabled),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore(exists: faceIDEnabled)
        )
    }

    func test_changeFirstNameTapped_hasNoSideEffects() {
        let sut = makeSut()
        sut.changeFirstNameTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeLastNameTapped_hasNoSideEffects() {
        let sut = makeSut()
        sut.changeLastNameTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeAddressTapped_hasNoSideEffects() {
        let sut = makeSut()
        sut.changeAddressTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeEmailTapped_hasNoSideEffects() {
        let sut = makeSut()
        sut.changeEmailTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }

    func test_changeContactNumberTapped_hasNoSideEffects() {
        let sut = makeSut()
        sut.changeContactNumberTapped()
        XCTAssertTrue(sut.faceIDEnabled)
    }
}
