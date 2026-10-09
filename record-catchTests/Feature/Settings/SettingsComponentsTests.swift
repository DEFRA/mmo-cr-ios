import XCTest
import SwiftUI
@testable import record_catch

/// Unit tests for the pure/testable logic behind the Settings components — the empty-state
/// value mapping (`SettingsValueRow.displayValue`) and the `UserDefaults`-backed analytics
/// preference store — plus rendering tests for `SettingsValueRow`'s SwiftUI `body` (see
/// `ViewRenderingHarness`).
@MainActor
final class SettingsComponentsTests: XCTestCase {

    // MARK: - SettingsValueRow.displayValue

    func test_displayValue_whenValuePresent_returnsValue() {
        XCTAssertEqual(
            SettingsValueRow.displayValue("Seine nets", emptyStateValue: "Not yet recorded"),
            "Seine nets"
        )
    }

    func test_displayValue_whenNil_returnsEmptyState() {
        XCTAssertEqual(
            SettingsValueRow.displayValue(nil, emptyStateValue: "Not yet recorded"),
            "Not yet recorded"
        )
    }

    func test_displayValue_whenEmptyString_returnsEmptyState() {
        XCTAssertEqual(
            SettingsValueRow.displayValue("", emptyStateValue: "Not yet recorded"),
            "Not yet recorded"
        )
    }

    // MARK: - UserDefaultsAnalyticsPreferenceStore

    func test_userDefaultsStore_defaultsToEnabled_whenNoValueStoredYet() {
        let defaults = UserDefaults(suiteName: "test.settings.analytics.\(UUID().uuidString)")!
        let sut = UserDefaultsAnalyticsPreferenceStore(defaults: defaults)

        XCTAssertTrue(sut.isAnalyticsEnabled())
    }

    func test_userDefaultsStore_persistsDisabledPreference() {
        let defaults = UserDefaults(suiteName: "test.settings.analytics.\(UUID().uuidString)")!
        let sut = UserDefaultsAnalyticsPreferenceStore(defaults: defaults)

        sut.setAnalyticsEnabled(false)

        XCTAssertFalse(sut.isAnalyticsEnabled())
    }

    func test_userDefaultsStore_persistsEnabledPreference_afterDisabling() {
        let defaults = UserDefaults(suiteName: "test.settings.analytics.\(UUID().uuidString)")!
        let sut = UserDefaultsAnalyticsPreferenceStore(defaults: defaults)

        sut.setAnalyticsEnabled(false)
        sut.setAnalyticsEnabled(true)

        XCTAssertTrue(sut.isAnalyticsEnabled())
    }

    // MARK: - InMemoryAnalyticsPreferenceStore

    func test_inMemoryStore_defaultsToTrue() {
        let sut = InMemoryAnalyticsPreferenceStore()
        XCTAssertTrue(sut.isAnalyticsEnabled())
    }

    func test_inMemoryStore_respectsInitialValue() {
        let sut = InMemoryAnalyticsPreferenceStore(initialValue: false)
        XCTAssertFalse(sut.isAnalyticsEnabled())
    }

    func test_inMemoryStore_roundTripsSetValue() {
        let sut = InMemoryAnalyticsPreferenceStore(initialValue: true)
        sut.setAnalyticsEnabled(false)
        XCTAssertFalse(sut.isAnalyticsEnabled())
    }

    // MARK: - SettingsValueRow rendering

    func test_render_populated() {
        ViewRenderingHarness.render(
            SettingsValueRow(
                label: "Gear used",
                value: "Seine nets",
                emptyStateValue: "Not yet recorded",
                changeTitle: "Change",
                changeAccessibilityIdentifier: "Settings.gearUsed.change",
                onChange: {}
            )
        )
    }

    func test_render_emptyState() {
        ViewRenderingHarness.render(
            SettingsValueRow(
                label: "Gear used",
                value: nil,
                emptyStateValue: "Not yet recorded",
                changeTitle: "Change",
                changeAccessibilityIdentifier: "Settings.gearUsed.change",
                onChange: {}
            )
        )
    }
}
