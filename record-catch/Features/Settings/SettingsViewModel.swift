import Foundation

/// View model for the Settings screen (see docs/design-specs/settings.md).
///
/// UI-only for most of this screen: the analytics toggle is backed by a local preference only
/// (no analytics SDK, no networking), "Gear used" reflects a locally-known value with an
/// authored empty state. "My account" pushes the real "Manage your account" screen via
/// `SettingsRouter` (see docs/adr/0007-settings-tab-navigation.md). "Sign out" is real
/// (ADR-0022 §9) — it calls through to `RootSessionCoordinator.handleSignOut()`. Every other
/// link/action below remains an inert seam with no destination or side effect wired up yet.
@MainActor
@Observable
final class SettingsViewModel {

    private let preferenceStore: AnalyticsPreferenceStoring
    private let router: SettingsRouter
    /// Calls `RootSessionCoordinator.handleSignOut()` (ADR-0022 §9) once the user confirms
    /// "Sign out". Defaults to a no-op for previews/tests that don't care about the app-root
    /// transition.
    private let onSignOut: () -> Void

    /// Backed by `AnalyticsPreferenceStoring` — every write is persisted immediately.
    ///
    /// - Note: Once real analytics consent lands (a future ADR), this should also notify
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

    /// Whether the "Sign out" confirmation dialog is presented. Tapping the link never
    /// signs out directly — it asks for confirmation first, matching the destructive
    /// confirmation pattern used elsewhere (e.g. `RemoveSpeciesViewModel`).
    private(set) var showSignOutConfirmation = false

    init(
        router: SettingsRouter? = nil,
        preferenceStore: AnalyticsPreferenceStoring = UserDefaultsAnalyticsPreferenceStore(),
        gearUsed: String? = nil,
        onSignOut: @escaping () -> Void = {
            // No-op default: previews/tests that don't exercise sign-out.
        }
    ) {
        self.router = router ?? SettingsRouter()
        self.preferenceStore = preferenceStore
        self.analyticsEnabled = preferenceStore.isAnalyticsEnabled()
        self.gearUsed = gearUsed
        self.onSignOut = onSignOut
    }

    /// The text to render for "Gear used" — `gearUsed` when recorded, or `emptyState`
    /// otherwise (never the Figma mock's literal placeholder "Cell" — see
    /// docs/design-specs/settings.md deviation #5).
    func gearUsedDisplayValue(emptyState: String) -> String {
        SettingsValueRow.displayValue(gearUsed, emptyStateValue: emptyState)
    }

    /// Reached via the "My account" link. Pushes the "Manage your account" screen (see
    /// `SettingsRoute.manageAccount` / docs/adr/0007-settings-tab-navigation.md). The only
    /// non-inert navigation seam on this screen — every other seam below remains a no-op.
    func myAccountTapped() {
        router.push(.manageAccount)
    }

    // MARK: - Inert seams
    //
    // None of the following navigates, signs out, or has any other side effect yet — all
    // destinations are unresolved per the design spec's Open questions. Each is a deliberate
    // no-op seam so the view has something concrete to call, and so wiring the real
    // destination later is a one-line change in exactly one place.

    /// Reached via the "Sign out" link. Presents a confirmation dialog before anything happens.
    func signOutTapped() {
        showSignOutConfirmation = true
    }

    /// Dismisses the sign-out confirmation dialog without making any change.
    func cancelSignOutConfirmation() {
        showSignOutConfirmation = false
    }

    /// Confirms "Sign out" from the dialog. Dismisses the dialog, clears the on-device
    /// favourites (ports, gears, species — see `FavouritesClearing`, ADR-0023) since favourites
    /// belong to the signed-in user and must not leak to whoever uses the app next, and calls
    /// through to `RootSessionCoordinator.handleSignOut()` (ADR-0022 §9), which signs out of
    /// MSAL, clears the local session/re-entry state, and returns the app root to the Sign In
    /// screen.
    func confirmSignOut(favouritesClearing: FavouritesClearing) {
        showSignOutConfirmation = false
        try? favouritesClearing.clearAllFavourites()
        onSignOut()
    }

    /// Reached via the Gear used row's "Change" link.
    /// - Note: Navigate to a gear-editing destination once one exists.
    func changeGearTapped() {
        // Intentionally empty: no destination exists yet (see note above).
    }

    /// Reached via the "Privacy notice" link.
    /// - Note: Navigate to (or open) the real privacy-notice destination.
    func privacyNoticeTapped() {
        // Intentionally empty: no destination exists yet (see note above).
    }

    /// Reached via the "Support information" link.
    /// - Note: Navigate to a support-information destination once one exists.
    func supportInformationTapped() {
        // Intentionally empty: no destination exists yet (see note above).
    }

    /// Reached via the "How we use your data" link below the analytics paragraph.
    /// - Note: Navigate to (or open) the real privacy-notice destination — likely the
    ///   same destination as `privacyNoticeTapped()`, to be confirmed with product.
    func openHowWeUseYourData() {
        // Intentionally empty: no destination exists yet (see note above).
    }
}
