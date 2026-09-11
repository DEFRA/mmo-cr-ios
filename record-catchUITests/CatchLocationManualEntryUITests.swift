//
//  CatchLocationManualEntryUITests.swift
//  record-catchUITests
//
//  Journey tests for the manual "Enter the statistical sub area…" screen reached from the
//  catch-location map's "Other" button (AC Scenario 10). Seeded straight to the screen via the
//  `-uiTestCatchRecordCatchLocationManualEntry` launch seam (see `UITestRootView`), since driving
//  the map itself is not assertable in XCUITest.
//

import XCTest

final class CatchLocationManualEntryUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.catchLocationManualEntry.heading"
        static let saveContinue = "CatchRecord.catchLocationManualEntry.saveContinue"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordCatchLocationManualEntry"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_manualEntry_showsHeadingAndSearchField() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.saveContinue).exists)
    }

    @MainActor
    func test_manualEntry_submitWithNoSelection_doesNotRoute() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        // "Save and continue" with no area chosen (arbitrary free text is never a valid area — the
        // same rule as the map screen). Must not proceed into the species sub-journey.
        app.buttons[ID.saveContinue].tap()

        XCTAssertTrue(element(app, ID.heading).exists)
        XCTAssertFalse(element(app, "CatchRecord.addSpecies.heading").exists)
        XCTAssertFalse(element(app, "CatchRecord.recordSpeciesWeights.heading").exists)
    }
}
