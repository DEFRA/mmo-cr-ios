//
//  NotificationsUITests.swift
//  record-catchUITests
//
//  Journey test for the Notifications placeholder screen (see ADR-0006), hosted via
//  the `-uiTestNotifications` launch argument.
//

import XCTest

final class NotificationsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestNotifications"]
        app.launch()
        return app
    }

    @MainActor
    func test_notificationsPlaceholder_showsHeadingAndBody() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["There are no notifications yet. This is where you'll see updates about your catch records."]
                .waitForExistence(timeout: 5)
        )

        // The Notifications tab is selected (see ADR-0006/TabBarUITests for the note on why tab
        // items are located by their localised label text rather than a custom identifier).
        XCTAssertTrue(app.tabBars.buttons["Notifications"].exists)
    }
}
