//
//  RecordSpeciesWeightsUITests.swift
//  record-catchUITests
//
//  Journey tests for the "Which species did you catch with <gear>?" weights screen and its
//  Add-species search (AC Scenarios 11 and 12). Seeded straight to the screen via the
//  `-uiTestCatchRecordSpeciesWeights` launch seam (see `UITestRootView`), which seeds one
//  favourite species (Atlantic cod) so the checkbox and its weight fields are present.
//

import XCTest

final class RecordSpeciesWeightsUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.recordSpeciesWeights.heading"
        static let saveContinue = "CatchRecord.recordSpeciesWeights.saveContinue"
        static let addSpecies = "CatchRecord.recordSpeciesWeights.addSpecies"
        // `idKey` in the view is `species.id.lowercased()`; the cod stub's id is its name.
        static let codOption = "CatchRecord.recordSpeciesWeights.option.atlantic cod (cod)"
        static let codWeightAbove = "CatchRecord.recordSpeciesWeights.weightAbove.atlantic cod (cod)"
        static let codAddBelow = "CatchRecord.recordSpeciesWeights.addBelow.atlantic cod (cod)"
        static let codAddDiscarded = "CatchRecord.recordSpeciesWeights.addDiscarded.atlantic cod (cod)"
        static let codWeightDiscarded = "CatchRecord.recordSpeciesWeights.weightDiscarded.atlantic cod (cod)"

        static let addSpeciesHeading = "CatchRecord.addSpecies.heading"
        static let addSpeciesSaveContinue = "CatchRecord.addSpecies.saveContinue"
        static let landingStorageHeading = "CatchRecord.landingStorage.heading"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordSpeciesWeights"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Weight fields conditional reveal

    @MainActor
    func test_tickingSpecies_revealsWeightFields() {
        let app = launch()

        let cod = element(app, ID.codOption)
        XCTAssertTrue(cod.waitForExistence(timeout: 5))

        // Weight fields are hidden until the species is ticked (GOV.UK conditional-reveal pattern).
        XCTAssertFalse(element(app, ID.codWeightAbove).exists)

        cod.tap()

        XCTAssertTrue(element(app, ID.codWeightAbove).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.codAddBelow).exists)
        XCTAssertTrue(element(app, ID.codAddDiscarded).exists)
    }

    // MARK: - Scenario 12: species recorded with only a legally-discarded weight

    @MainActor
    func test_speciesWithOnlyDiscardedWeight_savesAndContinuesToLandingStorage() {
        let app = launch()

        let cod = element(app, ID.codOption)
        XCTAssertTrue(cod.waitForExistence(timeout: 5))
        cod.tap()

        // Reveal the optional "legally discarded" field and enter a weight, leaving the
        // "above minimum size retained" field blank.
        let addDiscarded = element(app, ID.codAddDiscarded)
        XCTAssertTrue(addDiscarded.waitForExistence(timeout: 5))
        addDiscarded.tap()

        let discardedField = app.textFields[ID.codWeightDiscarded]
        XCTAssertTrue(discardedField.waitForExistence(timeout: 5))
        discardedField.tap()
        discardedField.typeText("12")

        // Dismiss the number pad by tapping the heading, then continue.
        element(app, ID.heading).tap()
        app.buttons[ID.saveContinue].tap()

        // Reaches the trip-level landing-storage question with only a discarded weight recorded.
        XCTAssertTrue(element(app, ID.landingStorageHeading).waitForExistence(timeout: 5))
    }

    // MARK: - Scenario 11: add another species via search (name + official code)

    @MainActor
    func test_addSpecies_searchByName_showsCodeAndReturnsToWeights() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        let addSpecies = element(app, ID.addSpecies)
        XCTAssertTrue(addSpecies.waitForExistence(timeout: 5))
        addSpecies.tap()

        XCTAssertTrue(element(app, ID.addSpeciesHeading).waitForExistence(timeout: 5))

        // Search the approved species list — results carry the official FAO code in the label.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Atlantic herring")

        let herringResult = element(app, "SearchDropdownField.result.Atlantic herring (HER)")
        XCTAssertTrue(herringResult.waitForExistence(timeout: 5))
        herringResult.tap()

        app.buttons[ID.addSpeciesSaveContinue].tap()

        // Returns to the weights screen, now offering the newly added species as an option.
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        XCTAssertTrue(
            element(app, "CatchRecord.recordSpeciesWeights.option.atlantic herring (her)").waitForExistence(timeout: 5)
        )
    }
}
