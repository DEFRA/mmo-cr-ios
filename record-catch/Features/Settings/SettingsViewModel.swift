import Foundation

/// View model for the Settings screen (see docs/design-specs/settings.md).
///
/// UI-only for this phase: the analytics toggle is backed by a local preference only (no
/// analytics SDK, no networking), "Gear used" reflects a locally-known value with an
/// authored empty state, and every link/action below is an inert seam — none has a real
/// destination or side effect wired up yet.
@MainActor
@Observable
final class SettingsViewModel {

    private let preferenceStore: AnalyticsPreferenceStoring

    /// Backed by `AnalyticsPreferenceStoring` — every write is persisted immediately.
    ///
    /// - TODO: Once real analytics consent lands (a future ADR), this should also notify
    ///   whatever consent-gate the analytics SDK reads, and likely need an explicit
    ///   "changes take effect next launch/immediately" decision.
    var analyticsEnabled: Bool {
        didSet {
            guard analyticsEnabled != oldValue else { return }
            preferenceStore.setAnalyticsEnabled(analyticsEnabled)
        }
    }

    /// The user's last-known "Gear used" value, or `nil` if none has been recorded yet.
    private(set) var gearUsed: String?

    init(
        preferenceStore: AnalyticsPreferenceStoring = UserDefaultsAnalyticsPreferenceStore(),
        gearUsed: String? = nil
    ) {
        self.preferenceStore = preferenceStore
        self.analyticsEnabled = preferenceStore.isAnalyticsEnabled()
        self.gearUsed = gearUsed
    }

    /// The text to render for "Gear used" — `gearUsed` when recorded, or `emptyState`
    /// otherwise (never the Figma mock's literal placeholder "Cell" — see
    /// docs/design-specs/settings.md deviation #5).
    func gearUsedDisplayValue(emptyState: String) -> String {
        SettingsValueRow.displayValue(gearUsed, emptyStateValue: emptyState)
    }

    // MARK: - Inert seams
    //
    // None of the following navigates, signs out, or has any other side effect yet — all
    // destinations are unresolved per the design spec's Open questions. Each is a deliberate
    // no-op seam so the view has something concrete to call, and so wiring the real
    // destination later is a one-line change in exactly one place.

    /// Reached via the "Sign out" link. **Inert** — no session exists yet, so there is
    /// nothing to sign out of, and this must not falsely imply an action occurred.
    /// - TODO: Wire real sign-out once authentication (ADR pending) exists.
    func signOutTapped() {}

    /// Reached via the Gear used row's "Change" link.
    /// - TODO: Navigate to a gear-editing destination once one exists.
    func changeGearTapped() {}

    /// Reached via the "My account" link.
    /// - TODO: Navigate to an account-details destination once one exists.
    func myAccountTapped() {}

    /// Reached via the "Privacy notice" link.
    /// - TODO: Navigate to (or open) the real privacy-notice destination.
    func privacyNoticeTapped() {}

    /// Reached via the "Support information" link.
    /// - TODO: Navigate to a support-information destination once one exists.
    func supportInformationTapped() {}

    /// Reached via the "How we use your data" link below the analytics paragraph.
    /// - TODO: Navigate to (or open) the real privacy-notice destination — likely the
    ///   same destination as `privacyNoticeTapped()`, to be confirmed with product.
    func openHowWeUseYourData() {}
}
