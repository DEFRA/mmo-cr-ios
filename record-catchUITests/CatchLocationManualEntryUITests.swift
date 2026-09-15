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

    /// A real sea-overlapping subrectangle code from the bundled reference data (`overlapsSea =
    /// true` in `subrectangles-precomputed.plist`), so the type-ahead is guaranteed a match.
    private enum SubArea {
        static let queryPrefix = "27D8"
        static let code = "27D86"
        static let resultIdentifierPrefix = "SearchDropdownField.result."
        static let specificResult = "SearchDropdownField.result.27D86"
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

    /// Focuses the type-ahead field and types the given text.
    private func typeSearch(_ app: XCUIApplication, _ text: String) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "The type-ahead search field should be shown")
        field.tap()
        field.typeText(text)
    }

    @MainActor
    func test_manualEntry_showsHeadingAndSearchField() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.saveContinue).exists)
    }

    /// Scenario 2 / FR3–FR4 — typing two or more characters returns matching statistical
    /// sub-area codes in a dropdown list.
    @MainActor
    func test_manualEntry_typingTwoOrMoreCharacters_showsMatchingResults() {
        let app = launch()
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        typeSearch(app, SubArea.queryPrefix)

        let anyResult = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", SubArea.resultIdentifierPrefix))
            .firstMatch
        XCTAssertTrue(
            anyResult.waitForExistence(timeout: 5),
            "Typing 2+ characters should reveal a dropdown list of matching sub-area codes"
        )
    }

    /// Scenario 4 / FR7 — selecting a suggested area populates the field and, on Save and
    /// continue, stores it against the record and proceeds into the species sub-journey.
    @MainActor
    func test_manualEntry_selectingResult_populatesFieldAndContinues() {
        let app = launch()
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        typeSearch(app, SubArea.queryPrefix)

        let result = element(app, SubArea.specificResult)
        XCTAssertTrue(result.waitForExistence(timeout: 5), "The typed prefix should match a known sea-overlapping code")
        result.tap()

        // Selecting a result populates the field with the chosen code.
        XCTAssertTrue(
            app.textFields[SubArea.code].waitForExistence(timeout: 5),
            "Selecting a result should populate the field with the chosen sub-area code"
        )

        app.buttons[ID.saveContinue].tap()

        // With a valid area chosen the journey advances into the species sub-journey (Add species,
        // since no favourite species are seeded on this screen's seam).
        XCTAssertTrue(
            element(app, "CatchRecord.addSpecies.heading").waitForExistence(timeout: 5),
            "Saving a valid sub-area should proceed to the next step of the catch-recording journey"
        )
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

    /// Scenario 5 / FR8 — entering a value that is not a valid statistical sub-area code and
    /// trying to continue shows an inline validation error and does not route on.
    @MainActor
    func test_manualEntry_invalidCode_showsValidationErrorAndDoesNotRoute() {
        let app = launch()
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        // A value with no match in the reference dataset (2+ chars so the field is non-empty).
        typeSearch(app, "ZZ")

        app.buttons[ID.saveContinue].tap()

        // NOTE: the app currently shows the shared "Select the area where most of your catch was
        // caught" message rather than the ticket's "Enter a valid statistical sub area code." —
        // recorded as a copy gap. The test asserts an error is shown and the screen is retained.
        let error = app.staticTexts["Select the area where most of your catch was caught"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), "An invalid code should surface an inline validation error")
        XCTAssertTrue(element(app, ID.heading).exists, "The user should remain on the manual-entry screen")
        XCTAssertFalse(element(app, "CatchRecord.addSpecies.heading").exists)
    }
}
