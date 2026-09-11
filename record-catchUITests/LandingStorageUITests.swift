//
//  LandingStorageUITests.swift
//  record-catchUITests
//
//  Journey tests for the "Is there any catch you will not be landing straight away?" Yes/No
//  question and the follow-on "not landing straight away" species screen (AC Scenarios 13 and 14).
//  Seeded straight to the screen via the `-uiTestCatchRecordLandingStorage` launch seam (see
//  `UITestRootView`), which seeds one favourite species so the "Yes" branch has an option to tick.
//

import XCTest

final class LandingStorageUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.landingStorage.heading"
        static let optionYes = "CatchRecord.landingStorage.option.yes"
        static let optionNo = "CatchRecord.landingStorage.option.no"
        static let saveContinue = "CatchRecord.landingStorage.saveContinue"
        static let error = "CatchRecord.landingStorage.error"

        static let speciesHeading = "CatchRecord.landingStorageSpecies.heading"
        static let speciesSaveContinue = "CatchRecord.landingStorageSpecies.saveContinue"
        static let codOption = "CatchRecord.landingStorageSpecies.option.atlantic cod (cod)"
        static let codWeight = "CatchRecord.landingStorageSpecies.weight.atlantic cod (cod)"

        static let checkYourAnswersHeading = "CatchRecord.checkYourAnswers.heading"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordLandingStorage"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_landingStorage_submitWithNoSelection_showsInlineError() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        app.buttons[ID.saveContinue].tap()

        XCTAssertTrue(element(app, ID.error).waitForExistence(timeout: 5))
        // Did not route on: still on the landing-storage question.
        XCTAssertTrue(element(app, ID.heading).exists)
    }

    // MARK: - Scenario 14: all catch landed

    @MainActor
    func test_landingStorage_no_continuesToCheckYourAnswers() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        element(app, ID.optionNo).tap()
        app.buttons[ID.saveContinue].tap()

        // "No" is not asked for stored-catch species and proceeds straight to the review.
        XCTAssertTrue(element(app, ID.checkYourAnswersHeading).waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, ID.speciesHeading).exists)
    }

    // MARK: - Scenario 13: catch not landed immediately

    @MainActor
    func test_landingStorage_yes_recordsStoredSpeciesWeight_thenCheckYourAnswers() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        element(app, ID.optionYes).tap()
        app.buttons[ID.saveContinue].tap()

        // "Yes" asks which species from the trip are being kept onboard/in keep pots.
        XCTAssertTrue(element(app, ID.speciesHeading).waitForExistence(timeout: 5))

        let cod = element(app, ID.codOption)
        XCTAssertTrue(cod.waitForExistence(timeout: 5))

        // Weight field is hidden until the species is ticked (conditional reveal).
        XCTAssertFalse(element(app, ID.codWeight).exists)
        cod.tap()

        let weightField = app.textFields[ID.codWeight]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.tap()
        weightField.typeText("8")

        // Dismiss the number pad by tapping the heading, then continue.
        element(app, ID.speciesHeading).tap()
        app.buttons[ID.speciesSaveContinue].tap()

        XCTAssertTrue(element(app, ID.checkYourAnswersHeading).waitForExistence(timeout: 5))
    }
}
