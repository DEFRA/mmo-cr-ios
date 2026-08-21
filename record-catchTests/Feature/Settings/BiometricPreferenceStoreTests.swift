import XCTest
@testable import record_catch

/// 100% coverage target — this is a security-adjacent local preference store (see
/// `BiometricPreferenceStore`'s doc comment on why it is a UI-only stub, not real biometrics).
final class BiometricPreferenceStoreTests: XCTestCase {

    // MARK: - UserDefaultsBiometricPreferenceStore

    func test_userDefaultsStore_defaultsToDisabled_whenNoValueStoredYet() {
        let defaults = UserDefaults(suiteName: "test.settings.faceID.\(UUID().uuidString)")!
        let sut = UserDefaultsBiometricPreferenceStore(defaults: defaults)

        XCTAssertFalse(sut.isFaceIDEnabled())
    }

    func test_userDefaultsStore_persistsEnabledPreference() {
        let defaults = UserDefaults(suiteName: "test.settings.faceID.\(UUID().uuidString)")!
        let sut = UserDefaultsBiometricPreferenceStore(defaults: defaults)

        sut.setFaceIDEnabled(true)

        XCTAssertTrue(sut.isFaceIDEnabled())
    }

    func test_userDefaultsStore_persistsDisabledPreference_afterEnabling() {
        let defaults = UserDefaults(suiteName: "test.settings.faceID.\(UUID().uuidString)")!
        let sut = UserDefaultsBiometricPreferenceStore(defaults: defaults)

        sut.setFaceIDEnabled(true)
        sut.setFaceIDEnabled(false)

        XCTAssertFalse(sut.isFaceIDEnabled())
    }

    // MARK: - InMemoryBiometricPreferenceStore

    func test_inMemoryStore_defaultsToFalse() {
        let sut = InMemoryBiometricPreferenceStore()
        XCTAssertFalse(sut.isFaceIDEnabled())
    }

    func test_inMemoryStore_respectsInitialValue() {
        let sut = InMemoryBiometricPreferenceStore(initialValue: true)
        XCTAssertTrue(sut.isFaceIDEnabled())
    }

    func test_inMemoryStore_roundTripsSetValue() {
        let sut = InMemoryBiometricPreferenceStore(initialValue: false)
        sut.setFaceIDEnabled(true)
        XCTAssertTrue(sut.isFaceIDEnabled())
    }
}
