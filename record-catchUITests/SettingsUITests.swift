//
//  SettingsUITests.swift
//  record-catchUITests
//
//  Journey tests for the Phase 2 Settings screen (see docs/design-specs/settings.md),
//  hosted via the `-uiTestSettings` launch argument. Covers the analytics-consent
//  toggle, the account/menu link list, and the "Gear used" row's empty state.
//

import XCTest

final class SettingsUITests: XCTestCase {

    private enum ID {
        static let title = "Settings"
        static let analyticsToggle = "Settings.analyticsToggle"
        static let linkMyAccount = "Settings.link.myAccount"
        static let linkPrivacyNotice = "Settings.link.privacyNotice"
        static let linkSupportInformation = "Settings.link.supportInformation"
        static let linkSignOut = "Settings.link.signOut"
        static let gearUsedChange = "Settings.gearUsed.change"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestSettings"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_settingsScreen_showsTitleAndAnalyticsSection() {
        let app = launch()

        XCTAssertTrue(app.staticTexts[ID.title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Optional analytics data"].exists)
        // "How we use your data" is a LinkButton: SwiftUI merges its Text label into a
        // single Button accessibility element, so it is exposed as a button, not a
        // separate static text.
        XCTAssertTrue(app.buttons["How we use your data"].exists)
        XCTAssertTrue(element(app, ID.analyticsToggle).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_analyticsToggle_flipsValue() {
        let app = launch()

        let toggle = element(app, ID.analyticsToggle)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        let initialValue = toggle.value as? String
        toggle.tap()

        // The toggle's underlying accessibility value ("1"/"0") flips after a tap —
        // asserted rather than a fixed expected value, since the persisted starting
        // state may vary run-to-run via `UserDefaults`.
        let flippedValue = toggle.value as? String
        XCTAssertNotEqual(initialValue, flippedValue, "Toggle's accessibility value should change after tapping")
    }

    @MainActor
    func test_menuLinks_reachableAndLabelled() {
        let app = launch()

        XCTAssertTrue(element(app, ID.linkMyAccount).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["My account"].exists)

        XCTAssertTrue(element(app, ID.linkPrivacyNotice).exists)
        XCTAssertTrue(app.staticTexts["Privacy notice"].exists)

        XCTAssertTrue(element(app, ID.linkSupportInformation).exists)
        XCTAssertTrue(app.staticTexts["Support information"].exists)

        XCTAssertTrue(element(app, ID.linkSignOut).exists)
        XCTAssertTrue(app.staticTexts["Sign out"].exists)
    }

    @MainActor
    func test_gearUsedRow_showsEmptyStateAndChangeLink() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Gear used"].waitForExistence(timeout: 5))
        // Empty state (deviation #5 — never the Figma mock's literal placeholder "Cell").
        XCTAssertTrue(app.staticTexts["Not yet recorded"].exists)
        XCTAssertFalse(app.staticTexts["Cell"].exists)

        XCTAssertTrue(element(app, ID.gearUsedChange).exists)
    }

    @MainActor
    func test_signOut_reachable_butDoesNotNavigateOrCrash() {
        let app = launch()

        let signOut = element(app, ID.linkSignOut)
        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        signOut.tap()

        // Inert seam: tapping "Sign out" has no destination yet — the Settings screen
        // (and its title) should still be showing, with no navigation/crash.
        XCTAssertTrue(app.staticTexts[ID.title].exists, "Sign out is inert — Settings should still be showing")
    }
}
