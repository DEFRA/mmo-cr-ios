//
//  CatchLocationNearestAreasUITests.swift
//  record-catchUITests
//
//  Journey tests for the "Select the statistical sub area…" nearest-areas radio-list screen
//  reached from the catch-location map's "Other" button. Seeded straight to the screen via the
//  `-uiTestCatchRecordCatchLocationNearestAreas` launch seam (see `UITestRootView`), which also
//  seeds a departure port (Plymouth) so the bundled, offline nearest-areas lookup has a real
//  coordinate to rank against — driving the map itself is not assertable in XCUITest.
//

import XCTest

final class CatchLocationNearestAreasUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.catchLocationNearestAreas.heading"
        static let saveContinue = "CatchRecord.catchLocationNearestAreas.saveContinue"
        static let error = "CatchRecord.catchLocationNearestAreas.error"
        static let otherOption = "CatchRecord.catchLocationNearestAreas.option.other"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordCatchLocationNearestAreas"]
        app.forwardReferenceDataAPIToken()
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Any radio option rendered by the shared `RadioGroup`/`RadioOption` components other than
    /// "Other" — i.e. one of the loaded nearest-area codes. `RadioOption` doesn't expose its own
    /// accessibility identifier (only the `RadioGroupOption`'s, applied by `RadioGroup` on the
    /// rendered view), so this matches on the `CatchRecord.catchLocationNearestAreas.option.`
    /// prefix every area row shares.
    private func firstAreaOption(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier != %@",
                "CatchRecord.catchLocationNearestAreas.option.", ID.otherOption
            ))
            .firstMatch
    }

    @MainActor
    func test_nearestAreas_showsHeadingAndOptions() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        XCTAssertTrue(
            firstAreaOption(app).waitForExistence(timeout: 5),
            "With a seeded departure port, at least one nearest area should be listed"
        )
        XCTAssertTrue(element(app, ID.otherOption).exists, "An \"Other\" option should always be offered")
        XCTAssertTrue(element(app, ID.saveContinue).exists)
    }

    @MainActor
    func test_nearestAreas_submitWithNoSelection_showsInlineError_andDoesNotRoute() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        app.buttons[ID.saveContinue].tap()

        XCTAssertTrue(element(app, ID.error).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.heading).exists)
    }

    /// Picking a listed area and continuing behaves exactly like tapping it on the map: it
    /// proceeds into the species sub-journey (Add species, since no favourite species are seeded
    /// on this screen's seam).
    @MainActor
    func test_nearestAreas_selectingAnArea_continuesToSpeciesSubJourney() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        let area = firstAreaOption(app)
        XCTAssertTrue(area.waitForExistence(timeout: 5))
        area.tap()

        app.buttons[ID.saveContinue].tap()

        XCTAssertTrue(
            element(app, "CatchRecord.addSpecies.heading").waitForExistence(timeout: 5),
            "Selecting a listed area and continuing should proceed to the next step of the journey"
        )
    }

    /// Picking "Other" and continuing navigates to the manual type-to-search screen instead of
    /// the species sub-journey.
    @MainActor
    func test_nearestAreas_selectingOther_navigatesToManualEntry() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        element(app, ID.otherOption).tap()

        app.buttons[ID.saveContinue].tap()

        XCTAssertTrue(
            element(app, "CatchRecord.catchLocationManualEntry.heading").waitForExistence(timeout: 5),
            "Selecting \"Other\" and continuing should navigate to the manual sub-area entry screen"
        )
    }
}
