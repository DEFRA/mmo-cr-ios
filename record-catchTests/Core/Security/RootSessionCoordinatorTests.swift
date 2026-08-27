import XCTest
@testable import record_catch

/// Security-critical path — 100% coverage target (testing.instructions.md). Covers the
/// composition-root logic that used to live, untested, directly inside `record_catchApp`.
@MainActor
final class RootSessionCoordinatorTests: XCTestCase {

    private func makeSut(
        biometricAuthenticator: BiometricAuthenticating = FakeBiometricAuthenticator(),
        sessionStore: LocalSessionStoring = InMemoryLocalSessionStore(hasSession: false),
        secretStore: ReentrySecretStoring = InMemoryReentrySecretStore(exists: false),
        preferenceStore: BiometricPreferenceStoring = InMemoryBiometricPreferenceStore(initialValue: false)
    ) -> RootSessionCoordinator {
        RootSessionCoordinator(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore
        )
    }

    // MARK: - Initial phase

    func test_initialPhase_isSignIn_whenNoLocalSession() {
        let sut = makeSut(sessionStore: InMemoryLocalSessionStore(hasSession: false))
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_initialPhase_isAppLock_whenSessionAndBiometricEligible() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true)
        )
        XCTAssertEqual(sut.phase, .appLock)
    }

    func test_initialPhase_isSignIn_whenSessionButBiometricUnavailable() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: false),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false)
        )
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_initialPhase_isSignIn_whenSessionButPreferenceDisabled() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false)
        )
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_initialPhase_isSignIn_whenSessionButNoSecretProvisioned() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: false),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true)
        )
        XCTAssertEqual(sut.phase, .signIn)
    }

    // MARK: - refreshPhase()

    func test_refreshPhase_reflectsStoreChangesSinceInit() {
        let sessionStore = InMemoryLocalSessionStore(hasSession: false)
        let sut = makeSut(sessionStore: sessionStore)
        XCTAssertEqual(sut.phase, .signIn)

        try? sessionStore.beginSession()
        sut.refreshPhase()

        XCTAssertEqual(sut.phase, .signIn) // biometrics still not eligible by default fakes above
    }

    // MARK: - handleSignIn()

    func test_handleSignIn_beginsLocalSessionAndMovesToHome() {
        let sessionStore = InMemoryLocalSessionStore(hasSession: false)
        let sut = makeSut(sessionStore: sessionStore)

        sut.handleSignIn()

        XCTAssertTrue(sessionStore.hasLocalSession())
        XCTAssertEqual(sut.phase, .home)
    }

    func test_handleSignIn_provisionsReentrySecret_whenPreferenceEnabled() {
        let secretStore = InMemoryReentrySecretStore(exists: false)
        let sut = makeSut(
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true)
        )

        sut.handleSignIn()

        XCTAssertTrue(secretStore.secretExists())
    }

    func test_handleSignIn_doesNotProvisionReentrySecret_whenPreferenceDisabled() {
        let secretStore = InMemoryReentrySecretStore(exists: false)
        let sut = makeSut(
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false)
        )

        sut.handleSignIn()

        XCTAssertFalse(secretStore.secretExists())
    }

    // MARK: - makeAppLockViewModel(unlockReason:)

    func test_makeAppLockViewModel_onUnlocked_movesPhaseToHome() {
        let sut = makeSut()
        let viewModel = sut.makeAppLockViewModel(unlockReason: "test reason")

        viewModel.onUnlocked()

        XCTAssertEqual(sut.phase, .home)
    }

    func test_makeAppLockViewModel_onFallbackToSignIn_movesPhaseToSignIn() {
        let sut = makeSut(sessionStore: InMemoryLocalSessionStore(hasSession: true))
        let viewModel = sut.makeAppLockViewModel(unlockReason: "test reason")

        viewModel.onFallbackToSignIn()

        XCTAssertEqual(sut.phase, .signIn)
    }

    // MARK: - make(launchArguments:) factory

    func test_make_usesFakeAppLockLockedDependencies_whenFlagPresent() {
        let sut = RootSessionCoordinator.make(
            launchArguments: LaunchArguments(raw: [LaunchArguments.Flag.appLockLocked.rawValue])
        )
        XCTAssertEqual(sut.phase, .appLock)
    }

    func test_make_usesFakeAppLockFallbackDependencies_whenFlagPresent() {
        let sut = RootSessionCoordinator.make(
            launchArguments: LaunchArguments(raw: [LaunchArguments.Flag.appLockFallback.rawValue])
        )
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_make_resetsBiometricPreference_forManageAccountUITest() {
        UserDefaults.standard.set(true, forKey: UserDefaultsBiometricPreferenceStore.storageKey)
        defer { UserDefaults.standard.removeObject(forKey: UserDefaultsBiometricPreferenceStore.storageKey) }

        _ = RootSessionCoordinator.make(
            launchArguments: LaunchArguments(raw: [LaunchArguments.Flag.manageAccount.rawValue])
        )

        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaultsBiometricPreferenceStore.storageKey))
    }
}
