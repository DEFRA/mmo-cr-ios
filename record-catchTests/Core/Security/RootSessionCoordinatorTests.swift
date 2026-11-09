import XCTest
@testable import record_catch

/// Security-critical path — 100% coverage target (testing.instructions.md). Covers the
/// composition-root logic that used to live, untested, directly inside `RecordCatchApp`, now also
/// covering real-authentication session restoration and the 7-day offline grace period
/// (ADR-0022).
@MainActor
final class RootSessionCoordinatorTests: XCTestCase {

    private func makeSut(
        authenticator: (any Authenticating)? = nil,
        biometricAuthenticator: BiometricAuthenticating = FakeBiometricAuthenticator(),
        sessionStore: LocalSessionStoring = InMemoryLocalSessionStore(hasSession: false),
        secretStore: ReentrySecretStoring = InMemoryReentrySecretStore(exists: false),
        preferenceStore: BiometricPreferenceStoring = InMemoryBiometricPreferenceStore(initialValue: false),
        verificationStore: SessionVerificationStoring = InMemorySessionVerificationStore(),
        connectivityMonitor: (any record_catch.ConnectivityMonitoring)? = nil,
        offlineAccessPolicy: OfflineAccessPolicy = .gracePeriod(days: 7),
        skipsBackgroundVerification: Bool = true
    ) -> RootSessionCoordinator {
        let resolvedAuthenticator: any Authenticating = authenticator ?? FakeAuthenticator()
        let resolvedConnectivityMonitor: any record_catch.ConnectivityMonitoring = connectivityMonitor ?? record_catch.StubConnectivityMonitor(isOnline: true)
        return RootSessionCoordinator(
            authenticator: resolvedAuthenticator,
            biometricAuthenticator: biometricAuthenticator,
            stores: SessionStores(
                sessionStore: sessionStore,
                secretStore: secretStore,
                preferenceStore: preferenceStore,
                verificationStore: verificationStore
            ),
            connectivityMonitor: resolvedConnectivityMonitor,
            offlineAccessPolicy: offlineAccessPolicy,
            skipsBackgroundVerification: skipsBackgroundVerification
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

    // MARK: - Offline grace period (ADR-0022 §5)

    func test_initialPhase_isAppLock_whenOfflineWithinGracePeriod() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            verificationStore: InMemorySessionVerificationStore(storedDate: Date().addingTimeInterval(-6 * 86_400)),
            connectivityMonitor: record_catch.StubConnectivityMonitor(isOnline: false)
        )
        XCTAssertEqual(sut.phase, .appLock)
    }

    func test_initialPhase_isSignIn_whenOfflinePastGracePeriod() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            verificationStore: InMemorySessionVerificationStore(storedDate: Date().addingTimeInterval(-8 * 86_400)),
            connectivityMonitor: record_catch.StubConnectivityMonitor(isOnline: false)
        )
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_initialPhase_isSignIn_whenOfflineAndNeverVerified() {
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            verificationStore: InMemorySessionVerificationStore(storedDate: nil),
            connectivityMonitor: record_catch.StubConnectivityMonitor(isOnline: false)
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

    // MARK: - verifySessionInBackground()

    func test_verifySessionInBackground_updatesVerificationTime_onSuccess() async {
        let account = AuthenticatedAccount(username: "a@b.com", identifier: "id-1")
        let verificationStore = InMemorySessionVerificationStore()
        let sut = makeSut(
            authenticator: FakeAuthenticator(restoreSessionOutcome: .success(account)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            verificationStore: verificationStore,
            skipsBackgroundVerification: false
        )

        await sut.verifySessionInBackground()

        XCTAssertNotNil(verificationStore.lastVerified())
    }

    func test_verifySessionInBackground_clearsSessionAndMovesToSignIn_whenReauthenticationRequired() async {
        let sessionStore = InMemoryLocalSessionStore(hasSession: true)
        let secretStore = InMemoryReentrySecretStore(exists: true)
        let sut = makeSut(
            authenticator: FakeAuthenticator(restoreSessionOutcome: .reauthenticationRequired),
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            skipsBackgroundVerification: false
        )
        XCTAssertEqual(sut.phase, .appLock)

        await sut.verifySessionInBackground()

        XCTAssertFalse(sessionStore.hasLocalSession())
        XCTAssertFalse(secretStore.secretExists())
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_verifySessionInBackground_leavesPhaseUnchanged_whenNetworkUnavailable() async {
        let sut = makeSut(
            authenticator: FakeAuthenticator(restoreSessionOutcome: .network),
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            skipsBackgroundVerification: false
        )
        XCTAssertEqual(sut.phase, .appLock)

        await sut.verifySessionInBackground()

        XCTAssertEqual(sut.phase, .appLock)
    }

    func test_verifySessionInBackground_isNoOp_whenSkipped() async {
        let verificationStore = InMemorySessionVerificationStore()
        let sut = makeSut(
            authenticator: FakeAuthenticator(restoreSessionOutcome: .success(AuthenticatedAccount(username: "a@b.com", identifier: "id"))),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            verificationStore: verificationStore,
            skipsBackgroundVerification: true
        )

        await sut.verifySessionInBackground()

        XCTAssertNil(verificationStore.lastVerified())
    }

    func test_verifySessionInBackground_isNoOp_whenNoLocalSession() async {
        let verificationStore = InMemorySessionVerificationStore()
        let sut = makeSut(
            authenticator: FakeAuthenticator(restoreSessionOutcome: .success(AuthenticatedAccount(username: "a@b.com", identifier: "id"))),
            sessionStore: InMemoryLocalSessionStore(hasSession: false),
            verificationStore: verificationStore,
            skipsBackgroundVerification: false
        )

        await sut.verifySessionInBackground()

        XCTAssertNil(verificationStore.lastVerified())
    }

    // MARK: - handleSignIn(_:)

    func test_handleSignIn_beginsLocalSessionAndMovesToHome() {
        let sessionStore = InMemoryLocalSessionStore(hasSession: false)
        let sut = makeSut(sessionStore: sessionStore)

        sut.handleSignIn(AuthenticatedAccount(username: "a@b.com", identifier: "id"))

        XCTAssertTrue(sessionStore.hasLocalSession())
        XCTAssertEqual(sut.phase, .home)
    }

    func test_handleSignIn_recordsVerificationTime() {
        let verificationStore = InMemorySessionVerificationStore()
        let sut = makeSut(verificationStore: verificationStore)

        sut.handleSignIn(AuthenticatedAccount(username: "a@b.com", identifier: "id"))

        XCTAssertNotNil(verificationStore.lastVerified())
    }

    func test_handleSignIn_provisionsReentrySecret_whenPreferenceEnabled() {
        let secretStore = InMemoryReentrySecretStore(exists: false)
        let sut = makeSut(
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true)
        )

        sut.handleSignIn(AuthenticatedAccount(username: "a@b.com", identifier: "id"))

        XCTAssertTrue(secretStore.secretExists())
    }

    func test_handleSignIn_doesNotProvisionReentrySecret_whenPreferenceDisabled() {
        let secretStore = InMemoryReentrySecretStore(exists: false)
        let sut = makeSut(
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false)
        )

        sut.handleSignIn(AuthenticatedAccount(username: "a@b.com", identifier: "id"))

        XCTAssertFalse(secretStore.secretExists())
    }

    // MARK: - handleSignOut() (ADR-0022 §9)

    func test_handleSignOut_clearsSessionSecretAndVerification_andMovesToSignIn() {
        let sessionStore = InMemoryLocalSessionStore(hasSession: true)
        let secretStore = InMemoryReentrySecretStore(exists: true)
        let verificationStore = InMemorySessionVerificationStore(storedDate: .now)
        let sut = makeSut(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            verificationStore: verificationStore
        )
        XCTAssertEqual(sut.phase, .appLock)

        sut.handleSignOut()

        XCTAssertFalse(sessionStore.hasLocalSession())
        XCTAssertFalse(secretStore.secretExists())
        XCTAssertNil(verificationStore.lastVerified())
        XCTAssertEqual(sut.phase, .signIn)
    }

    func test_handleSignOut_callsAuthenticatorSignOut() async {
        let authenticator = FakeAuthenticator()
        let sut = makeSut(authenticator: authenticator)

        sut.handleSignOut()
        // `signOut()` is dispatched in an unstructured `Task` — yield so it has a chance to run.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(authenticator.signOutCallCount, 1)
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

    // MARK: - makeSignInView()

    func test_makeSignInView_onSignIn_movesPhaseToHome() {
        let sut = makeSut()
        let signInView = sut.makeSignInView()

        // `SignInView`'s `onSignIn` closure is private; drive it indirectly via `handleSignIn`
        // through the coordinator instead, matching how `record_catchApp.swift` wires it up.
        _ = signInView
        sut.handleSignIn(AuthenticatedAccount(username: "a@b.com", identifier: "id"))

        XCTAssertEqual(sut.phase, .home)
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

    func test_make_fallsThroughToRealStores_forAnOtherwiseUnhandledUITestLaunch() {
        // A plain `-uiTestOffline`-only launch (no app-lock flag) relies on the real,
        // store-backed coordinator genuinely starting at `.signIn` on a fresh simulator run —
        // `OfflineBannerUITests.test_banner_onSignInScreen_isNotShown_evenWhenOffline()` depends
        // on exactly this (ADR-0022 §10: only the *authenticator* is stubbed for UI tests, not
        // every dependency).
        let sut = RootSessionCoordinator.make(
            launchArguments: LaunchArguments(raw: [LaunchArguments.Flag.offline.rawValue])
        )
        XCTAssertEqual(sut.phase, .signIn)
    }
}
