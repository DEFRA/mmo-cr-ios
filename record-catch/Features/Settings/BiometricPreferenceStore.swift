import Foundation

/// The user's local Face ID sign-in preference, shown as a toggle on the "Manage your account"
/// screen's "Sign in" section.
///
/// This preference is now the **real** opt-in switch for the offline biometric local re-entry
/// gate (see ADR-0009, `AppLockView`/`AppLockViewModel`, and `Core/Security/`). It is still
/// **not** backend authentication — no real backend authentication exists in this app yet; this
/// only gates re-entry into an already-local "signed-in" app state. See
/// `ManageAccountViewModel.faceIDEnabled` for the enrolment-gated write path — turning the
/// preference on requires a live, successful biometric check first; it is never flipped on
/// speculatively.
nonisolated protocol BiometricPreferenceStoring: Sendable {
    /// Whether the user has opted in to Face ID sign-in.
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
