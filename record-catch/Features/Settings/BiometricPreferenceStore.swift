import Foundation

/// The user's local Face ID sign-in preference, shown as a toggle on the "Manage your account"
/// screen's "Sign in" section.
///
/// **UI-only stub for this phase — deliberately NOT wired to `LocalAuthentication`.** No
/// `LAContext`/`evaluatePolicy` call is made anywhere in this app yet, and no biometric
/// enrolment/consent has actually happened; this only persists a local on/off preference so the
/// toggle has a real value to bind to and survives relaunches, mirroring
/// `AnalyticsPreferenceStoring`. See docs/design-specs/manage-account.md and
/// docs/adr/0007-settings-tab-navigation.md for the security follow-up this stub defers.
///
/// - TODO: Wiring real Face ID sign-in requires a dedicated security-reviewed ADR covering
///   `LAContext` policy evaluation, Keychain-backed credential storage, `NSFaceIDUsageDescription`
///   (currently absent — this app uses `GENERATE_INFOPLIST_FILE=YES` with no biometrics usage
///   description, correctly, since no real biometric API is called), and graceful fallback when
///   biometrics are unavailable/unenrolled. Do not let this preference drive any real
///   authentication decision until that ADR lands.
nonisolated protocol BiometricPreferenceStoring: Sendable {
    /// Whether the user has opted in to Face ID sign-in (UI preference only).
    func isFaceIDEnabled() -> Bool
    /// Persists the user's choice.
    func setFaceIDEnabled(_ enabled: Bool)
}

/// `UserDefaults`-backed implementation, defaulting to opted-out (`false`) to match the Figma
/// mock's "off" toggle state.
nonisolated final class UserDefaultsBiometricPreferenceStore: BiometricPreferenceStoring, @unchecked Sendable {
    static let storageKey = "settings.faceIDEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isFaceIDEnabled() -> Bool {
        defaults.bool(forKey: Self.storageKey)
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.storageKey)
    }
}

/// In-memory, UI-only preference store — used by previews/tests so they never touch real
/// `UserDefaults` state.
nonisolated final class InMemoryBiometricPreferenceStore: BiometricPreferenceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled: Bool

    init(initialValue: Bool = false) {
        self.enabled = initialValue
    }

    func isFaceIDEnabled() -> Bool {
        lock.withLock { enabled }
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        lock.withLock { self.enabled = enabled }
    }
}
