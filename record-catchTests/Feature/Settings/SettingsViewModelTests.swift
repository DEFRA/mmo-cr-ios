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

    func test_confirmSignOut_dismissesDialog_clearsFavouritesAndCallsOnSignOut() {
        var signOutCallCount = 0
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store, gearUsed: "Seine nets", onSignOut: { signOutCallCount += 1 })
        sut.signOutTapped()

        sut.confirmSignOut(favouritesClearing: NoOpFavouritesClearing())

        XCTAssertFalse(sut.showSignOutConfirmation)
        XCTAssertEqual(signOutCallCount, 1)
        // Unrelated Settings state is unaffected by sign-out.
        XCTAssertTrue(sut.analyticsEnabled)
        XCTAssertEqual(sut.gearUsed, "Seine nets")
    }

    func test_confirmSignOut_clearsFavourites() {
        let store = InMemoryAnalyticsPreferenceStore(initialValue: true)
        let sut = SettingsViewModel(preferenceStore: store)
        sut.signOutTapped()
        let clearing = SpyFavouritesClearing()

        sut.confirmSignOut(favouritesClearing: clearing)

        XCTAssertEqual(clearing.clearCallCount, 1)
    }

    func test_cancelSignOutConfirmation_doesNotCallOnSignOut() {
        var signOutCallCount = 0
        let sut = SettingsViewModel(preferenceStore: InMemoryAnalyticsPreferenceStore(), onSignOut: { signOutCallCount += 1 })
        sut.signOutTapped()

        sut.cancelSignOutConfirmation()

        XCTAssertEqual(signOutCallCount, 0)
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

/// Records how many times `clearAllFavourites` is called, so
/// `test_confirmSignOut_clearsFavourites` can assert it without a real `ModelContext`.
@MainActor
private final class SpyFavouritesClearing: FavouritesClearing {
    private(set) var clearCallCount = 0

    func clearAllFavourites() throws {
        clearCallCount += 1
    }
}
