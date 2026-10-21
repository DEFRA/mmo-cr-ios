import XCTest
@testable import record_catch

@MainActor
final class SettingsViewModelTests: XCTestCase {

    func test_init_defaultsAnalyticsEnabled_fromPreferenceStore() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        XCTAssertTrue(sut.analyticsEnabled)
    }

    func test_init_readsExistingDisabledPreference() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: false)
        let sut = SettingsViewModel(preferenceStore: store)

        XCTAssertFalse(sut.analyticsEnabled)
    }

    func test_settingAnalyticsEnabled_toFalse_persistsToStore() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.analyticsEnabled = false

        XCTAssertFalse(store.isAnalyticsEnabled())
    }

    func test_settingAnalyticsEnabled_toTrue_persistsToStore() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: false)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.analyticsEnabled = true

        XCTAssertTrue(store.isAnalyticsEnabled())
    }

    func test_settingAnalyticsEnabled_toSameValue_doesNotRewriteStore() {
        // Uses a spy so we can assert the write path is only exercised on a genuine change.
        let store = SpyAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.analyticsEnabled = true

        XCTAssertEqual(store.setCallCount, 0)
    }

    // MARK: - Gear used

    func test_gearUsed_nilByDefault_mapsToEmptyStateCopy() {
        let sut = SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore())

        XCTAssertNil(sut.gearUsed)
        XCTAssertEqual(sut.gearUsedDisplayValue(emptyState: "Not yet recorded"), "Not yet recorded")
    }

    func test_gearUsed_whenProvided_isReturnedAsIs() {
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            gearUsed: "Seine nets"
        )

        XCTAssertEqual(sut.gearUsed, "Seine nets")
        XCTAssertEqual(sut.gearUsedDisplayValue(emptyState: "Not yet recorded"), "Seine nets")
    }

    func test_gearUsed_whenEmptyString_mapsToEmptyStateCopy() {
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            gearUsed: ""
        )

        XCTAssertEqual(sut.gearUsedDisplayValue(emptyState: "Not yet recorded"), "Not yet recorded")
    }

    // MARK: - Inert seams
    //
    // Every seam below is a deliberate no-op in this phase (see SettingsViewModel). These
    // tests assert calling them has no observable side effect on unrelated state.

    func test_signOutTapped_presentsConfirmationDialog_withNoOtherSideEffects() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store, gearUsed: "Seine nets")

        sut.signOutTapped()

        XCTAssertTrue(sut.showSignOutConfirmation)
        XCTAssertTrue(sut.analyticsEnabled)
        XCTAssertEqual(sut.gearUsed, "Seine nets")
    }

    func test_cancelSignOutConfirmation_dismissesDialog_hasNoOtherSideEffects() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store, gearUsed: "Seine nets")
        sut.signOutTapped()

        sut.cancelSignOutConfirmation()

        XCTAssertFalse(sut.showSignOutConfirmation)
        XCTAssertTrue(sut.analyticsEnabled)
        XCTAssertEqual(sut.gearUsed, "Seine nets")
    }

    func test_confirmSignOut_dismissesDialog_remainsInert() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store, gearUsed: "Seine nets")
        sut.signOutTapped()

        sut.confirmSignOut()

        // Inert: still no session/auth exists, so confirming has no side effect beyond
        // dismissing the dialog — analytics preference and gear used are unaffected.
        XCTAssertFalse(sut.showSignOutConfirmation)
        XCTAssertTrue(sut.analyticsEnabled)
        XCTAssertEqual(sut.gearUsed, "Seine nets")
    }

    func test_myAccountTapped_pushesManageAccountRoute() {
        let router = SettingsRouter()
        let sut = SettingsViewModel(router: router, preferenceStore: InMemoryAnalyticsPreferenceStore())

        sut.myAccountTapped()

        XCTAssertEqual(router.path, [.manageAccount])
    }

    func test_privacyNoticeTapped_hasNoSideEffects() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.privacyNoticeTapped()

        XCTAssertTrue(sut.analyticsEnabled)
    }

    func test_supportInformationTapped_hasNoSideEffects() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.supportInformationTapped()

        XCTAssertTrue(sut.analyticsEnabled)
    }

    func test_openHowWeUseYourData_hasNoSideEffects() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)

        sut.openHowWeUseYourData()

        XCTAssertTrue(sut.analyticsEnabled)
    }

    func test_changeGearTapped_hasNoSideEffects() {
        let sut = SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore(), gearUsed: "Seine nets")

        sut.changeGearTapped()

        XCTAssertEqual(sut.gearUsed, "Seine nets")
    }

    // MARK: - TEMPORARY DEBUG-ONLY: species reference-data smoke check
    //
    // Covers `SettingsViewModel`'s `#if DEBUG`-only `debugFetchSpeciesTapped()` seam (see its doc
    // comment) — an error-handling/networking path, so this must stay at 100% coverage per
    // testing.instructions.md for as long as the temporary feature exists.

    func test_debugFetchSpeciesTapped_onSuccess_populatesResultMessageWithSpeciesNames() async throws {
        let species = [SpeciesOption(name: "Atlantic cod (COD)"), SpeciesOption(name: "Haddock (HAD)")]
        let client = StubReferenceDataClient(species: species)
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertFalse(sut.isFetchingDebugSpecies)
        XCTAssertTrue(sut.isShowingDebugSpeciesResultAlert)
        let message = try XCTUnwrap(sut.debugSpeciesResultMessage)
        XCTAssertTrue(message.contains("2 species"))
        XCTAssertTrue(message.contains("Atlantic cod (COD)"))
        XCTAssertTrue(message.contains("Haddock (HAD)"))
    }

    func test_debugFetchSpeciesTapped_onEmptySuccess_populatesZeroCountMessage() async {
        let client = StubReferenceDataClient(species: [])
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertEqual(sut.debugSpeciesResultMessage, "Fetched 0 species.")
    }

    func test_debugFetchSpeciesTapped_onAPIError_populatesFailureMessage() async {
        let client = StubReferenceDataClient(error: .response(status: 503, details: nil))
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertFalse(sut.isFetchingDebugSpecies)
        let message = try? XCTUnwrap(sut.debugSpeciesResultMessage)
        XCTAssertEqual(message, "Fetch failed: HTTP 503 (unknown).")
    }

    func test_debugFetchSpeciesTapped_onOfflineError_populatesOfflineMessage() async {
        let client = StubReferenceDataClient(error: .offline)
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertEqual(sut.debugSpeciesResultMessage, "Fetch failed: device appears offline.")
    }

    func test_debugFetchSpeciesTapped_onTimeout_populatesTimeoutMessage() async {
        let client = StubReferenceDataClient(error: .timedOut)
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertEqual(sut.debugSpeciesResultMessage, "Fetch failed: request timed out.")
    }

    func test_debugFetchSpeciesTapped_onInvalidConfiguration_populatesConfigurationMessage() async {
        let client = StubReferenceDataClient(error: .invalidConfiguration)
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertEqual(sut.debugSpeciesResultMessage, "Fetch failed: invalid API configuration.")
    }

    func test_debugFetchSpeciesTapped_onDecodingError_populatesDecodingMessage() async {
        let client = StubReferenceDataClient(error: .decoding("bad shape"))
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )

        await sut.debugFetchSpeciesTapped()

        XCTAssertEqual(sut.debugSpeciesResultMessage, "Fetch failed: could not decode response (bad shape).")
    }

    func test_isShowingDebugSpeciesResultAlert_settingFalse_clearsResultMessage() async {
        let client = StubReferenceDataClient(species: [SpeciesOption(name: "Atlantic cod (COD)")])
        let sut = SettingsViewModel(
            preferenceStore: InMemoryAnalyticsPreferenceStore(),
            debugReferenceDataClient: client
        )
        await sut.debugFetchSpeciesTapped()
        XCTAssertTrue(sut.isShowingDebugSpeciesResultAlert)

        sut.isShowingDebugSpeciesResultAlert = false

        XCTAssertFalse(sut.isShowingDebugSpeciesResultAlert)
        XCTAssertNil(sut.debugSpeciesResultMessage)
    }
}

/// Records how many times `setAnalyticsEnabled` is called, so tests can assert the
/// view model skips redundant writes when the value doesn't actually change.
private final class SpyAnalyticsPreferenceStore: AnalyticsPreferenceStoring, @unchecked Sendable {
    private(set) var setCallCount = 0
    private var enabled: Bool

    init(initialValue: Bool) {
        self.enabled = initialValue
    }

    func isAnalyticsEnabled() -> Bool { enabled }

    func setAnalyticsEnabled(_ enabled: Bool) {
        setCallCount += 1
        self.enabled = enabled
    }
}
