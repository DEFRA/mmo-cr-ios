import Foundation

/// View model for the "Manage your account" screen (see docs/design-specs/manage-account.md).
///
/// UI-only for this phase: `account` comes from a stub, local-only `AccountProviding` fixture
/// (no networking), `faceIDEnabled` is backed by a local `BiometricPreferenceStoring` preference
/// only — **not** real biometrics (no `LocalAuthentication`/`LAContext` anywhere in this app yet,
/// see `BiometricPreferenceStore`) — and every "Change" link is an inert seam mirroring
/// `SettingsViewModel`'s existing inert seams.
@MainActor
@Observable
final class ManageAccountViewModel {

    private let biometricStore: BiometricPreferenceStoring

    /// The signed-in user's account details, loaded once from `AccountProviding` at init.
    let account: Account

    /// Backed by `BiometricPreferenceStoring` — every write is persisted immediately. UI-only
    /// stub: toggling this does **not** call any biometric API.
    ///
    /// - TODO: Wiring real Face ID sign-in needs a dedicated security-reviewed ADR (see
    ///   `BiometricPreferenceStore`'s doc comment) before this preference drives any actual
    ///   authentication.
    var faceIDEnabled: Bool {
        didSet {
            guard faceIDEnabled != oldValue else { return }
            biometricStore.setFaceIDEnabled(faceIDEnabled)
        }
    }

    init(
        accountProvider: AccountProviding = StubAccountProvider(),
        biometricStore: BiometricPreferenceStoring = UserDefaultsBiometricPreferenceStore()
    ) {
        self.account = accountProvider.currentAccount()
        self.biometricStore = biometricStore
        self.faceIDEnabled = biometricStore.isFaceIDEnabled()
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
