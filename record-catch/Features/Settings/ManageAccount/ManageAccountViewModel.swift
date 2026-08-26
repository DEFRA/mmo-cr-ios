import Foundation

/// View model for the "Manage your account" screen (see docs/design-specs/manage-account.md).
///
/// UI-only for this phase: `account` comes from a stub, local-only `AccountProviding` fixture
/// (no networking), and every "Change" link is an inert seam mirroring `SettingsViewModel`'s
/// existing inert seams. The Face ID toggle, however, is now **real** (ADR-0009): turning it on
/// requires a live, successful biometric evaluation before the preference is persisted and a
/// re-entry secret is provisioned; a failed/unavailable check leaves the preference untouched
/// and surfaces `enableFailedMessage`. This still gates only a device-local re-entry
/// convenience — no real backend authentication exists in this app yet.
@MainActor
@Observable
final class ManageAccountViewModel {

    private let biometricStore: BiometricPreferenceStoring
    private let biometricAuthenticator: BiometricAuthenticating
    private let secretStore: ReentrySecretStoring
    private let enableCheckReason: String

    /// The signed-in user's account details, loaded once from `AccountProviding` at init.
    let account: Account

    /// Backed by `BiometricPreferenceStoring`. Setting this to `true` triggers a live biometric
    /// enrolment check (`enableFaceID()`); most callers should use that method directly rather
    /// than assigning here, since a direct assignment cannot await the check. The view binds via
    /// `enableFaceID()`/`disableFaceID()` (see `ManageAccountView`).
    private(set) var faceIDEnabled: Bool

    /// Set when a `enableFaceID()` attempt fails (biometrics unavailable/not enrolled/cancelled).
    /// Cleared automatically on the next attempt. Surfaced as an accessible inline error (text +
    /// icon, never colour alone) — see `ManageAccountView`.
    private(set) var enableFailedMessage: Bool = false

    init(
        accountProvider: AccountProviding = StubAccountProvider(),
        biometricStore: BiometricPreferenceStoring = UserDefaultsBiometricPreferenceStore(),
        biometricAuthenticator: BiometricAuthenticating = LABiometricAuthenticator(),
        secretStore: ReentrySecretStoring = KeychainReentrySecretStore(),
        enableCheckReason: String = "Turn on Face ID sign-in"
    ) {
        self.account = accountProvider.currentAccount()
        self.biometricStore = biometricStore
        self.biometricAuthenticator = biometricAuthenticator
        self.secretStore = secretStore
        self.enableCheckReason = enableCheckReason
        self.faceIDEnabled = biometricStore.isFaceIDEnabled()
    }

    /// Attempts to turn Face ID re-entry on: runs a live biometric check first (ADR-0009 §8).
    /// Only on success is the preference persisted and a re-entry secret provisioned. On
    /// failure/unavailability/cancellation, the preference stays `false` and
    /// `enableFailedMessage` is set.
    func enableFaceID() async {
        do {
            try await biometricAuthenticator.authenticate(reason: enableCheckReason)
            try secretStore.provisionSecret()
            biometricStore.setFaceIDEnabled(true)
            faceIDEnabled = true
            enableFailedMessage = false
        } catch {
            enableFailedMessage = true
        }
    }

    /// Turns Face ID re-entry off: clears the stored re-entry secret and persists the preference.
    func disableFaceID() {
        try? secretStore.clearSecret()
        biometricStore.setFaceIDEnabled(false)
        faceIDEnabled = false
        enableFailedMessage = false
    }

    // MARK: - Inert seams
    //
    // None of the following navigates or has any other side effect yet — the real destinations
    // are unresolved (see design spec's Open questions). Each is a deliberate no-op seam so the
    // view has something concrete to call, mirroring `SettingsViewModel`'s existing pattern.

    /// Reached via the First name row's "Change" link.
    /// - TODO: Navigate to a first-name-editing destination once one exists.
    func changeFirstNameTapped() {}

    /// Reached via the Last name row's "Change" link.
    /// - TODO: Navigate to a last-name-editing destination once one exists.
    func changeLastNameTapped() {}

    /// Reached via the Address row's "Change" link.
    /// - TODO: Navigate to an address-editing destination once one exists.
    func changeAddressTapped() {}

    /// Reached via the Email row's "Change" link.
    /// - TODO: Navigate to an email-editing destination once one exists.
    func changeEmailTapped() {}

    /// Reached via the Contact number row's "Change" link.
    /// - TODO: Navigate to a contact-number-editing destination once one exists.
    func changeContactNumberTapped() {}
}
