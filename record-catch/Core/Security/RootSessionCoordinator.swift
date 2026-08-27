//
//  RootSessionCoordinator.swift
//  record-catch
//
//  Composition root for the local session / offline biometric re-entry flow (ADR-0009).
//
//  `isSignedIn` is gone: a device-local "session" persists across relaunches via `sessionStore`
//  (Keychain-backed, NOT a backend session — no real authentication exists yet). `phase` decides
//  which of sign-in / app-lock / home `record_catchApp` shows, computed via the pure
//  `BiometricReentryPolicy` helper so the *decision* logic stays unit-tested there; this type only
//  wires the stores together and exposes the resulting phase + intents, and is itself unit-tested
//  (see `RootSessionCoordinatorTests`) — this logic used to live, untested, directly inside the
//  `App` entry point.
//

import Foundation

/// Which of sign-in / app-lock / home the app root should show (ADR-0009).
enum RootPhase: Equatable {
    case signIn
    case appLock
    case home
}

@MainActor
@Observable
final class RootSessionCoordinator {
    private(set) var phase: RootPhase

    private let biometricAuthenticator: BiometricAuthenticating
    private let sessionStore: LocalSessionStoring
    private let secretStore: ReentrySecretStoring
    private let preferenceStore: BiometricPreferenceStoring

    init(
        biometricAuthenticator: BiometricAuthenticating,
        sessionStore: LocalSessionStoring,
        secretStore: ReentrySecretStoring,
        preferenceStore: BiometricPreferenceStoring
    ) {
        self.biometricAuthenticator = biometricAuthenticator
        self.sessionStore = sessionStore
        self.secretStore = secretStore
        self.preferenceStore = preferenceStore
        self.phase = Self.computePhase(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore
        )
    }

    /// Re-evaluates `phase` from current store state — called when returning to the foreground
    /// after backgrounding (ADR-0009 §4).
    func refreshPhase() {
        phase = Self.computePhase(
            biometricAuthenticator: biometricAuthenticator,
            sessionStore: sessionStore,
            secretStore: secretStore,
            preferenceStore: preferenceStore
        )
    }

    /// Runs after the (currently stubbed) sign-in succeeds: begins the local session and, if the
    /// user has previously opted in to Face ID re-entry, re-provisions the secret defensively
    /// (idempotent — a no-op if one is already provisioned).
    func handleSignIn() {
        try? sessionStore.beginSession()
        if preferenceStore.isFaceIDEnabled() {
            try? secretStore.provisionSecret()
        }
        phase = .home
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

    private static func computePhase(
        biometricAuthenticator: BiometricAuthenticating,
        sessionStore: LocalSessionStoring,
        secretStore: ReentrySecretStoring,
        preferenceStore: BiometricPreferenceStoring
    ) -> RootPhase {
        guard sessionStore.hasLocalSession() else { return .signIn }
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
    /// Builds the coordinator with real (Keychain/`LocalAuthentication`-backed) dependencies, or
    /// deterministic in-memory fakes when a UI-test launch argument requests a specific app-lock
    /// state (ADR-0009) — mirroring the `-uiTest*` launch-arg pattern used elsewhere in the app.
    static func make(launchArguments: LaunchArguments = .current) -> RootSessionCoordinator {
        if launchArguments.contains(.appLockLocked) {
            return RootSessionCoordinator(
                biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
                sessionStore: InMemoryLocalSessionStore(hasSession: true),
                secretStore: InMemoryReentrySecretStore(exists: true),
                preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true)
            )
        }

        if launchArguments.contains(.appLockFallback) {
            return RootSessionCoordinator(
                biometricAuthenticator: FakeBiometricAuthenticator(availability: .unavailable(.noBiometryEnrolled)),
                sessionStore: InMemoryLocalSessionStore(hasSession: true),
                secretStore: InMemoryReentrySecretStore(exists: false),
                preferenceStore: InMemoryBiometricPreferenceStore(initialValue: false)
            )
        }

        // Deterministic starting point for Settings/Manage-account UI tests (mirrors
        // `-uiTestResetLanguage`): the real `UserDefaultsBiometricPreferenceStore` persists across
        // launches, and the toggle's "on" path now requires a real (simulator-absent) biometric
        // check, so tests need a known "off" starting value.
        if launchArguments.contains(.manageAccount) || launchArguments.contains(.settings) {
            UserDefaults.standard.removeObject(forKey: UserDefaultsBiometricPreferenceStore.storageKey)
        }

        return RootSessionCoordinator(
            biometricAuthenticator: LABiometricAuthenticator(),
            sessionStore: KeychainLocalSessionStore(),
            secretStore: KeychainReentrySecretStore(),
            preferenceStore: UserDefaultsBiometricPreferenceStore()
        )
    }
}
