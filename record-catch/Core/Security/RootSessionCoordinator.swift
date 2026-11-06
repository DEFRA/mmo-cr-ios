//
//  RootSessionCoordinator.swift
//  record-catch
//
//  Composition root for the local session / offline biometric re-entry flow (ADR-0009), now
//  backed by real Entra authentication (ADR-0022).
//
//  `phase` decides which of sign-in / app-lock / home `RecordCatchApp` shows. The session check
//  (ADR-0022 §5) runs first, synchronously from local state (never blocking cold launch on the
//  network); a background online refresh can only move the user *to* sign-in after the fact if it
//  discovers the session is no longer valid — it never silently claims success while offline.
//

import Foundation

/// Which of sign-in / app-lock / home the app root should show (ADR-0009).
enum RootPhase: Equatable {
    case signIn
    case appLock
    case home
}

/// Bundles the four local-session/offline-re-entry store dependencies (ADR-0009/ADR-0022) into
/// one value, keeping `RootSessionCoordinator.init` within SonarCloud's 7-parameter limit
/// (swift:S107) without changing how the class addresses each store individually internally.
struct SessionStores {
    let sessionStore: LocalSessionStoring
    let secretStore: ReentrySecretStoring
    let preferenceStore: BiometricPreferenceStoring
    let verificationStore: SessionVerificationStoring
}

@MainActor
@Observable
final class RootSessionCoordinator {
    private(set) var phase: RootPhase

    private let authenticator: any Authenticating
    private let biometricAuthenticator: BiometricAuthenticating
    private let sessionStore: LocalSessionStoring
    private let secretStore: ReentrySecretStoring
    private let preferenceStore: BiometricPreferenceStoring
    private let verificationStore: SessionVerificationStoring
    private let connectivityMonitor: ConnectivityMonitoring
    private let offlineAccessPolicy: OfflineAccessPolicy
    /// `true` for every `-uiTest*` launch (ADR-0022 §10): skips the background silent-refresh
    /// check, since `FakeAuthenticator`/`UITestStubAuthenticator.restoreSession()` always reports
    /// `.noAccount` (neither fake tracks a session independently of `signIn` having been called),
    /// which would otherwise incorrectly bounce every UI test that seeds a local session straight
    /// to sign-in.
    private let skipsBackgroundVerification: Bool

    init(
        authenticator: any Authenticating,
        biometricAuthenticator: BiometricAuthenticating,
        stores: SessionStores,
        connectivityMonitor: ConnectivityMonitoring,
        offlineAccessPolicy: OfflineAccessPolicy = .current,
        skipsBackgroundVerification: Bool = false
    ) {
        self.authenticator = authenticator
        self.biometricAuthenticator = biometricAuthenticator
        self.sessionStore = stores.sessionStore
        self.secretStore = stores.secretStore
        self.preferenceStore = stores.preferenceStore
        self.verificationStore = stores.verificationStore
        self.connectivityMonitor = connectivityMonitor
        self.offlineAccessPolicy = offlineAccessPolicy
        self.skipsBackgroundVerification = skipsBackgroundVerification
        self.phase = Self.computeLocalPhase(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore,
            verificationStore: verificationStore,
            connectivityMonitor: connectivityMonitor,
            offlineAccessPolicy: offlineAccessPolicy
        )
    }

    /// Re-evaluates `phase` from current store state — called when returning to the foreground
    /// after backgrounding (ADR-0009 §4), and kicks off a background silent session check
    /// (ADR-0022 §5) that can move the user to sign-in if the session is no longer valid.
    func refreshPhase() {
        phase = Self.computeLocalPhase(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore,
            verificationStore: verificationStore,
            connectivityMonitor: connectivityMonitor,
            offlineAccessPolicy: offlineAccessPolicy
        )
        guard !skipsBackgroundVerification else { return }
        Task { await verifySessionInBackground() }
    }

    /// Attempts a silent online session refresh and reconciles `phase` with the outcome
    /// (ADR-0022 §5). A no-op if there is no local session to begin with, or if this coordinator
    /// skips background verification (`-uiTest*` launches — see `skipsBackgroundVerification`).
    func verifySessionInBackground() async {
        guard !skipsBackgroundVerification, sessionStore.hasLocalSession() else { return }

        switch await authenticator.restoreSession() {
        case .success:
            try? verificationStore.markVerified(.now)
        case .noAccount, .reauthenticationRequired:
            try? sessionStore.endSession()
            try? secretStore.clearSecret()
            try? verificationStore.clear()
            phase = .signIn
        case .network:
            // Offline: leave `phase` as already computed from the local policy check.
            break
        }
    }

    /// Runs after a successful sign-in: begins the local session, records the verification time,
    /// and — if the user has previously opted in to Face ID re-entry — re-provisions the secret
    /// defensively (idempotent — a no-op if one is already provisioned).
    func handleSignIn(_: AuthenticatedAccount) {
        try? sessionStore.beginSession()
        try? verificationStore.markVerified(.now)
        if preferenceStore.isFaceIDEnabled() {
            try? secretStore.provisionSecret()
        }
        phase = .home
    }

    /// Signs out (ADR-0022 §9): clears MSAL's cache, the local session marker, the biometric
    /// re-entry secret, and the session-verification time, then returns to the sign-in screen.
    func handleSignOut() {
        Task { await authenticator.signOut() }
        try? sessionStore.endSession()
        try? secretStore.clearSecret()
        try? verificationStore.clear()
        phase = .signIn
    }

    /// Builds a fully-configured `AppLockViewModel` for the app-lock branch of the app root.
    func makeAppLockViewModel(unlockReason: String) -> AppLockViewModel {
        let viewModel = AppLockViewModel(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore,
            unlockReason: unlockReason
        )
        viewModel.onUnlocked = { [weak self] in self?.phase = .home }
        viewModel.onFallbackToSignIn = { [weak self] in self?.phase = .signIn }
        return viewModel
    }

    /// Builds a `SignInViewModel`-backed `SignInView` sharing this coordinator's authenticator.
    func makeSignInView() -> SignInView {
        SignInView(authenticator: authenticator, onSignIn: { [weak self] account in
            self?.handleSignIn(account)
        })
    }

    /// Decides the phase from local state only (no network): no local session → sign-in;
    /// otherwise, online presumed reachable (a background check corrects this — see
    /// `verifySessionInBackground()`) or within the offline grace period → fall through to the
    /// existing ADR-0009 biometric-reentry decision; past the grace period while offline →
    /// sign-in (ADR-0022 §5).
    private static func computeLocalPhase(
        biometricAuthenticator: BiometricAuthenticating,
        sessionStore: LocalSessionStoring,
        secretStore: ReentrySecretStoring,
        preferenceStore: BiometricPreferenceStoring,
        verificationStore: SessionVerificationStoring,
        connectivityMonitor: ConnectivityMonitoring,
        offlineAccessPolicy: OfflineAccessPolicy
    ) -> RootPhase {
        guard sessionStore.hasLocalSession() else { return .signIn }

        if !connectivityMonitor.isOnline {
            let allowed = offlineAccessPolicy.allowsOfflineAccess(lastVerified: verificationStore.lastVerified())
            guard allowed else { return .signIn }
        }

        let offer = BiometricReentryPolicy.offer(
            hasLocalSession: true,
            preferenceEnabled: preferenceStore.isFaceIDEnabled(),
            availability: biometricAuthenticator.biometricAvailability(),
            secretExists: secretStore.secretExists()
        )
        switch offer {
        case .offer: return .appLock
        case .fallToSignIn: return .signIn
        }
    }
}

// MARK: - Factory

extension RootSessionCoordinator {
    /// Builds the coordinator with real (Keychain/`LocalAuthentication`/MSAL-backed) dependencies,
    /// or deterministic in-memory fakes when a UI-test launch argument requests a specific state
    /// (ADR-0009/ADR-0022) — mirroring the `-uiTest*` launch-arg pattern used elsewhere in the app.
    ///
    /// - Parameter connectivityMonitor: the app-wide connectivity signal (ADR-0019). The real app
    ///   launch (`RecordCatchApp`) must pass its own, already-started `connectivityMonitor` here,
    ///   so `MSALNativeAuthenticator` and this coordinator's offline check observe the *same*
    ///   `NWPathMonitor` instance rather than standing up a second one. Defaults to `nil`, which
    ///   falls back to an always-online stub — fine for tests and for `-uiTest*` launches that
    ///   fall through to this real-store branch (e.g. a bare `-uiTestOffline`, which forces its
    ///   own offline state at the `ConnectivityMonitoring` seam closer to the UI instead; see
    ///   `RecordCatchApp.makeConnectivityMonitor()`).
    static func make(
        launchArguments: LaunchArguments = .current,
        connectivityMonitor: (any ConnectivityMonitoring)? = nil
    ) -> RootSessionCoordinator {
        // Any `-uiTest*` launch forces the authenticator stub (ADR-0022 §10) so no XCUITest run
        // ever depends on network access to a real Entra tenant.
        let resolvedConnectivityMonitor = connectivityMonitor ?? StubConnectivityMonitor(isOnline: true)
        let authenticator: any Authenticating = launchArguments.isUITesting
            ? FakeAuthenticator.makeUITestStub()
            : MSALNativeAuthenticator.make(connectivityMonitor: resolvedConnectivityMonitor)

        if launchArguments.contains(.appLockLocked) {
            return RootSessionCoordinator(
                authenticator: authenticator,
                biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
                stores: SessionStores(
                    sessionStore: InMemoryLocalSessionStore(hasSession: true),
                    secretStore: InMemoryReentrySecretStore(exists: true),
                    preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
                    verificationStore: InMemorySessionVerificationStore(storedDate: .now)
                ),
                connectivityMonitor: StubConnectivityMonitor(isOnline: true),
                skipsBackgroundVerification: true
            )
        }

        if launchArguments.contains(.appLockFallback) {
            return RootSessionCoordinator(
                authenticator: authenticator,
                biometricAuthenticator: FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled)),
                stores: SessionStores(
                    sessionStore: InMemoryLocalSessionStore(hasSession: true),
                    secretStore: InMemoryReentrySecretStore(exists: false),
                    preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false),
                    verificationStore: InMemorySessionVerificationStore(storedDate: .now)
                ),
                connectivityMonitor: StubConnectivityMonitor(isOnline: true),
                skipsBackgroundVerification: true
            )
        }

        // Deterministic starting point for Settings/Manage-account UI tests (mirrors
        // `-uiTestResetLanguage`): the real `UserDefaultsBiometricPreferenceStore` persists across
        // launches, and the toggle's "on" path now requires a real (simulator-absent) biometric
        // check, so tests need a known "off" starting value.
        if launchArguments.contains(.manageAccount) || launchArguments.contains(.settings) {
            UserDefaults.standard.removeObject(forKey: UserDefaultsBiometricPreferenceStore.storageKey)
        }

        // Every other `-uiTest*` launch falls through to the real, store-backed coordinator below
        // (still with the authenticator stub from above). Most UI-test launch arguments are
        // handled by `UITestRootView`, which substitutes its own seeded screen *before*
        // `sessionCoordinator.phase` is ever consulted — but a handful (e.g. a bare
        // `-uiTestOffline`) are not, and rely on this coordinator's phase genuinely starting at
        // `.signIn` on a fresh simulator run, exactly as a real first launch would.
        return RootSessionCoordinator(
            authenticator: authenticator,
            biometricAuthenticator: LABiometricAuthenticator(),
            stores: SessionStores(
                sessionStore: KeychainLocalSessionStore(),
                secretStore: KeychainReentrySecretStore(),
                preferenceStore: UserDefaultsBiometricPreferenceStore(),
                verificationStore: KeychainSessionVerificationStore()
            ),
            connectivityMonitor: resolvedConnectivityMonitor
        )
    }
}
