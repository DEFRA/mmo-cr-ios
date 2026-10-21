import Foundation

/// View model for the Settings screen (see docs/design-specs/settings.md).
///
/// UI-only for this phase: the analytics toggle is backed by a local preference only (no
/// analytics SDK, no networking), "Gear used" reflects a locally-known value with an
/// authored empty state. "My account" pushes the real "Manage your account" screen via
/// `SettingsRouter` (see docs/adr/0007-settings-tab-navigation.md); every other link/action
/// below remains an inert seam with no destination or side effect wired up yet.
@MainActor
@Observable
final class SettingsViewModel {

    private let preferenceStore: AnalyticsPreferenceStoring
    private let router: SettingsRouter

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

    #if DEBUG || ENABLE_DEBUG_REFERENCE_DATA_TOOL
    // MARK: - TEMPORARY DEBUG-ONLY: species reference-data smoke check
    //
    // ⚠️ Remove this entire `#if DEBUG` block (and its counterpart in SettingsView.swift) before
    // release — see the loud "DEBUG BUILD ONLY" button it backs. Gating on `#if DEBUG` means it is
    // physically impossible for this to reach a Release/App Store build (security.instructions.md
    // "no debug backdoors in release builds"), but it must still be deleted once no longer needed
    // for manual verification of the reference-data connector (ADR-0018).

    /// The connector used by `debugFetchSpeciesTapped()`. Defaults to the real
    /// `RemoteReferenceDataClient`, constructed exactly like
    /// `verifyReferenceDataConnectivity()` in `ReferenceDataDevSmokeCheck.swift`; injectable so
    /// tests can supply a `StubReferenceDataClient` instead of touching the network.
    private let debugReferenceDataClient: ReferenceDataFetching

    /// Whether the DEBUG-only species fetch is in flight.
    private(set) var isFetchingDebugSpecies = false

    /// The message to show in the DEBUG-only result alert, once a fetch has completed.
    private(set) var debugSpeciesResultMessage: String?

    /// Binding target for the DEBUG-only result `.alert()` in `SettingsView`.
    var isShowingDebugSpeciesResultAlert: Bool {
        get { debugSpeciesResultMessage != nil }
        set { if !newValue { debugSpeciesResultMessage = nil } }
    }
    #endif

    init(
        router: SettingsRouter? = nil,
        preferenceStore: AnalyticsPreferenceStoring = UserDefaultsAnalyticsPreferenceStore(),
        gearUsed: String? = nil
    ) {
        self.router = router ?? SettingsRouter()
        self.preferenceStore = preferenceStore
        self.analyticsEnabled = preferenceStore.isAnalyticsEnabled()
        self.gearUsed = gearUsed
        #if DEBUG || ENABLE_DEBUG_REFERENCE_DATA_TOOL
        self.debugReferenceDataClient = Self.makeDefaultDebugReferenceDataClient()
        #endif
    }

    #if DEBUG || ENABLE_DEBUG_REFERENCE_DATA_TOOL
    /// Test-only seam so `SettingsViewModelTests` can inject a `StubReferenceDataClient` in place
    /// of the network-backed connector. Compiled only in DEBUG — never reaches a Release build.
    init(
        router: SettingsRouter? = nil,
        preferenceStore: AnalyticsPreferenceStoring = UserDefaultsAnalyticsPreferenceStore(),
        gearUsed: String? = nil,
        debugReferenceDataClient: ReferenceDataFetching
    ) {
        self.router = router ?? SettingsRouter()
        self.preferenceStore = preferenceStore
        self.analyticsEnabled = preferenceStore.isAnalyticsEnabled()
        self.gearUsed = gearUsed
        self.debugReferenceDataClient = debugReferenceDataClient
    }

    /// Mirrors `verifyReferenceDataConnectivity()`'s construction of the real connector. Falls
    /// back to a stub that always reports `.invalidConfiguration` when `APIConfiguration` can't be
    /// resolved, so an un-configured Debug build shows a clear alert instead of crashing.
    private static func makeDefaultDebugReferenceDataClient() -> ReferenceDataFetching {
        guard let configuration = try? APIConfiguration() else {
            return StubReferenceDataClient(error: .invalidConfiguration)
        }
        return RemoteReferenceDataClient(
            httpClient: URLSessionHTTPClient(),
            configuration: configuration,
            tokenProvider: EnvironmentTokenProvider()
        )
    }

    /// Reached via the temporary DEBUG-only "Fetch species (API)" button. Calls the live
    /// reference-data API's `species` dataset and surfaces the result (a short summary of the
    /// decoded species, or the failure) in an alert — see `isShowingDebugSpeciesResultAlert`.
    /// Never compiled into a Release build; this is a manual connectivity check only
    /// (ADR-0018), not a production feature.
    func debugFetchSpeciesTapped() async {
        guard !isFetchingDebugSpecies else { return }
        isFetchingDebugSpecies = true
        defer { isFetchingDebugSpecies = false }

        do {
            let species = try await debugReferenceDataClient.fetchSpecies()
            debugSpeciesResultMessage = Self.debugSuccessMessage(for: species)
        } catch let error as APIError {
            debugSpeciesResultMessage = Self.debugFailureMessage(for: error)
        } catch {
            debugSpeciesResultMessage = "Fetch failed: \(error.localizedDescription)"
        }
    }

    /// Builds a non-sensitive, human-readable summary of a successful species fetch — the count
    /// plus up to the first 5 names — never raw response content.
    private static func debugSuccessMessage(for species: [SpeciesOption]) -> String {
        guard !species.isEmpty else { return "Fetched 0 species." }
        let sample = species.prefix(5).map(\.name).joined(separator: ", ")
        let suffix = species.count > 5 ? "…" : ""
        return "Fetched \(species.count) species.\n\(sample)\(suffix)"
    }

    /// Builds a non-sensitive, human-readable summary of a failed species fetch — status/error
    /// code only, never the token, headers or raw response body.
    private static func debugFailureMessage(for error: APIError) -> String {
        switch error {
        case .invalidConfiguration:
            return "Fetch failed: invalid API configuration."
        case .offline:
            return "Fetch failed: device appears offline."
        case .timedOut:
            return "Fetch failed: request timed out."
        case let .decoding(details):
            return "Fetch failed: could not decode response (\(details))."
        case let .response(status, details):
            let code = details?.code ?? "unknown"
            return "Fetch failed: HTTP \(status) (\(code))."
        }
    }
    #endif

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

    /// Reached via the "Sign out" link. Presents a confirmation dialog before anything
    /// happens — the dialog's own confirm action (`confirmSignOut()`) remains **inert**,
    /// since no session exists yet, so this must not falsely imply an action occurred.
    /// - Note: Inert pending authentication (ADR pending) — wire real sign-out once it exists.
    func signOutTapped() {
        showSignOutConfirmation = true
    }

    /// Dismisses the sign-out confirmation dialog without making any change.
    func cancelSignOutConfirmation() {
        showSignOutConfirmation = false
    }

    /// Confirms "Sign out" from the dialog. **Inert** — no session exists yet, so there is
    /// nothing to sign out of; only dismisses the dialog.
    /// - Note: Inert pending authentication (ADR pending) — wire real sign-out once it exists.
    func confirmSignOut() {
        showSignOutConfirmation = false
        // Intentionally no further action: no session exists to sign out of yet (see note above).
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
