//
//  TabBarUITests.swift
//  record-catchUITests
//
//  Journey tests for the root TabView (see ADR-0006): tab switching, tab-bar
//  visibility on each tab's root, and the tab bar hiding while the "Create a catch
//  record" journey is in progress and reappearing on returning to Home.
//

import XCTest

final class TabBarUITests: XCTestCase {

    // NOTE: SwiftUI's `.tabItem { Label(...).accessibilityIdentifier(...) }` does not reliably
    // propagate the custom identifier onto the underlying `UITabBarButton` at the OS level, so
    // tab items are located by their (English, via `-uiTestResetLanguage`) localised label text
    // via `app.tabBars.buttons[...]` instead -- the same stable pattern XCUITest itself uses for
    // system tab bars. The `TabBar.home`/`.notifications`/`.settings` accessibility identifiers
    // are still set in `RootTabView` for VoiceOver/other tooling, but are not relied on here.
    private enum ID {
        static let createRecord = "Home.createRecordButton"
        static let selectVesselGroup = "CatchRecord.selectVessel.radioGroup"
    }

    private enum TabLabel {
        static let home = "Home"
        static let notifications = "Notifications"
        static let settings = "Settings"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestTabBar"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tabButton(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.tabBars.buttons[label]
    }

    @MainActor
    func test_tabBar_visibleOnHome_andSwitchesTabs() {
        let app = launch()

        XCTAssertTrue(tabButton(app, TabLabel.home).waitForExistence(timeout: 5))
        XCTAssertTrue(tabButton(app, TabLabel.notifications).exists)
        XCTAssertTrue(tabButton(app, TabLabel.settings).exists)

        // Home content is visible by default.
        XCTAssertTrue(element(app, ID.createRecord).exists)

        tabButton(app, TabLabel.notifications).tap()
        XCTAssertTrue(tabButton(app, TabLabel.home).exists, "Tab bar should remain visible on Notifications")
        XCTAssertTrue(tabButton(app, TabLabel.notifications).exists)
        XCTAssertTrue(tabButton(app, TabLabel.settings).exists)

        tabButton(app, TabLabel.settings).tap()
        XCTAssertTrue(tabButton(app, TabLabel.home).exists, "Tab bar should remain visible on Settings")

        tabButton(app, TabLabel.home).tap()
        XCTAssertTrue(element(app, ID.createRecord).waitForExistence(timeout: 5), "Should return to Home content")
    }

    @MainActor
    func test_tabBar_hidesDuringJourney_andReappearsOnReturnToHome() {
        let app = launch()

        let createRecord = element(app, ID.createRecord)
        XCTAssertTrue(createRecord.waitForExistence(timeout: 5))
        XCTAssertTrue(tabButton(app, TabLabel.home).isHittable, "Tab bar should be visible on Home")

        createRecord.tap()

        let selectVesselGroup = element(app, ID.selectVesselGroup)
        XCTAssertTrue(selectVesselGroup.waitForExistence(timeout: 5))
        XCTAssertFalse(
            tabButton(app, TabLabel.home).isHittable,
            "Tab bar should be hidden while the Create-a-catch-record journey is in progress"
        )
        XCTAssertFalse(tabButton(app, TabLabel.notifications).isHittable)
        XCTAssertFalse(tabButton(app, TabLabel.settings).isHittable)

        // Navigate back to Home via the custom header's back link.
        let backButton = element(app, "ViewHeader.backButton")
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertTrue(createRecord.waitForExistence(timeout: 5))
        XCTAssertTrue(tabButton(app, TabLabel.home).isHittable, "Tab bar should reappear back on Home")
    }
}
