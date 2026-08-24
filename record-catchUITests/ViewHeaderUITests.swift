//
//  ViewHeaderUITests.swift
//  record-catchUITests
//
//  Verifies the shared `ViewHeader` branding mark (an image since the GOV.UK
//  wordmark artwork replaced the text label) still exposes an accessible
//  "GOV.UK" label, and that the back button / language toggle controls either
//  side of it are unaffected by the change.
//

import XCTest

final class ViewHeaderUITests: XCTestCase {

    private enum ID {
        static let branding = "ViewHeader.branding"
        static let backButton = "ViewHeader.backButton"
        static let languageToggle = "Header.languageToggle"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestHome"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_header_brandingImage_hasGovUKAccessibilityLabel() {
        let app = launch()

        let branding = element(app, ID.branding)
        XCTAssertTrue(branding.waitForExistence(timeout: 5))
        XCTAssertEqual(branding.label, "GOV.UK")
    }

    @MainActor
    func test_header_backButtonAndLanguageToggle_remainPresentAlongsideBranding() {
        let app = launch()

        XCTAssertTrue(element(app, ID.branding).waitForExistence(timeout: 5))

        // On the Home root there is no screen to pop back to, so the back
        // control is hidden (removed from the accessibility tree) and not hittable.
        let backButton = element(app, ID.backButton)
        XCTAssertFalse(backButton.isHittable, "Back button should be hidden on a journey root")

        let languageToggle = element(app, ID.languageToggle)
        XCTAssertTrue(languageToggle.exists)
        XCTAssertTrue(languageToggle.isHittable, "Language toggle should remain usable")
    }
}
