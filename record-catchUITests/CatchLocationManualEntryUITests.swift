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

    // MARK: - Evidence-capture walkthrough ("Enter Statistical Sub Area Using 'Other' Option")

    private enum GearSeamID {
        static let option = "CatchRecord.selectGear.option.sx"
        static let timesShotField = "CatchRecord.selectGear.variable.sx.timesShot"
        static let heading = "CatchRecord.selectGear.heading"
        static let saveContinue = "CatchRecord.selectGear.saveContinue"
    }

    private enum CatchLocationMapID {
        static let heading = "CatchRecord.catchLocation.heading"
        static let otherButton = "CatchRecord.catchLocation.otherButton"
    }

    /// Attaches a full-screen screenshot to the test as QA evidence, kept even on a passing run so
    /// it's retrievable from the resulting `.xcresult` bundle (mirrors `CatchLocationUITests`).
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    /// Launches at the "What gear did you use?" screen via the existing seam (mirrors
    /// `CatchLocationUITests.launch()`), used only to reach the map screen for the S1 steps below.
    private func launchAtSelectGear() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordSelectGear"]
        app.launch()
        return app
    }

    /// Drives the select-gear steps (mirrors `CatchLocationUITests.reachCatchLocationMap()`) so
    /// the catch-location map's "Other" control is reachable for S1a/S1b below.
    @MainActor
    private func reachCatchLocationMap() -> XCUIApplication {
        let app = launchAtSelectGear()

        let option = element(app, GearSeamID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5), "The select-gear seam should show the gear option")
        option.tap()

        let field = app.textFields[GearSeamID.timesShotField]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Ticking the gear should reveal its measurement field")
        field.tap()
        field.typeText("5")

        element(app, GearSeamID.heading).tap()
        app.buttons[GearSeamID.saveContinue].tap()

        XCTAssertTrue(
            element(app, CatchLocationMapID.heading).waitForExistence(timeout: 5),
            "Continuing from select gear should open the catch-location map heading"
        )
        return app
    }

    /// Evidence-capture walkthrough for the "Enter Statistical Sub Area Using 'Other' Option"
    /// ticket, part 1 (S1a/S1b) — the catch-location map's "Other" control and the manual-entry
    /// screen it reveals. This test asserts **current** app behaviour (see the inline `GAP`
    /// comment for where it diverges from the ticket) and must keep passing unchanged.
    @MainActor
    func test_statisticalSubArea_otherOption_evidenceWalkthrough_mapRevealsManualEntry() {
        // S1a — the catch-location map screen showing the "Other" control.
        let app = reachCatchLocationMap()
        let otherButton = element(app, CatchLocationMapID.otherButton)
        // GAP (FR1/S1): the ticket asks for a radio button beneath a suggested sub-area list; this
        // build instead offers a floating "Other" button overlaid on the map — see
        // `CatchLocationView.otherButton`.
        XCTAssertTrue(otherButton.waitForExistence(timeout: 5), "The map should offer an \"Other\" control")
        attachScreenshot(named: "S1-CatchLocation-OtherControl", app: app)

        // S1b — tapping "Other" reveals the manual-entry type-ahead screen.
        otherButton.tap()
        XCTAssertTrue(
            element(app, ID.heading).waitForExistence(timeout: 5),
            "Tapping \"Other\" should reveal the manual-entry screen"
        )
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5), "The type-ahead field should be shown")
        attachScreenshot(named: "S1-ManualEntry-TypeAheadRevealed", app: app)
    }

    /// Evidence-capture walkthrough, part 2 (S2–S4) — type-ahead search, narrowing to a single
    /// match and selecting a result. Seeded straight to the manual-entry screen (as the other
    /// tests in this file do) so it doesn't depend on re-driving the map by hand.
    @MainActor
    func test_statisticalSubArea_otherOption_evidenceWalkthrough_searchAndSelect() {
        let app = launch()
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))

        // S2a — typing 1 character does not yet reveal any results (minimumCharacters = 2 on
        // `SearchDropdownField`).
        typeSearch(app, String(SubArea.queryPrefix.prefix(1)))
        let anyResultAfterOneChar = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", SubArea.resultIdentifierPrefix))
            .firstMatch
        XCTAssertFalse(anyResultAfterOneChar.exists, "Typing a single character should not reveal any dropdown results")
        attachScreenshot(named: "S2-OneChar-NoResults", app: app)

        // S2b — typing 2+ characters reveals matching sub-area codes.
        app.textFields.firstMatch.typeText(String(SubArea.queryPrefix.dropFirst(1)))
        let firstResult = element(app, SubArea.specificResult)
        XCTAssertTrue(
            firstResult.waitForExistence(timeout: 5),
            "Typing 2+ characters should reveal matching sub-area codes"
        )
        // GAP (FR5/S2): the ticket asks each result row to also show coordinates and the related
        // ICES rectangle; this build's row label is the bare code only — see
        // `SearchDropdownField`'s `Button(option)` result row, where the label IS the option
        // string. Asserting equality here documents that current, narrower behaviour.
        XCTAssertEqual(
            firstResult.label,
            SubArea.code,
            "Current behaviour: the result row's label is the bare code only, with no coordinates or ICES rectangle"
        )
        attachScreenshot(named: "S2-TwoChars-ResultsShown", app: app)

        // S3 — narrowing the query to a single match still shows no coordinate readout anywhere.
        app.textFields.firstMatch.typeText(String(SubArea.code.dropFirst(SubArea.queryPrefix.count)))
        let narrowedResults = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", SubArea.resultIdentifierPrefix))
        XCTAssertEqual(narrowedResults.count, 1, "Narrowing the query should leave exactly one matching result")
        // GAP (FR6/S3): the ticket asks coordinates to auto-appear once the code narrows to a
        // valid match; this build has no coordinate readout anywhere on the manual-entry screen.
        attachScreenshot(named: "S3-Narrowed-NoCoordinateReadout", app: app)

        // S4 — selecting the result populates the field, and Save and continue proceeds.
        element(app, SubArea.specificResult).tap()
        XCTAssertTrue(
            app.textFields[SubArea.code].waitForExistence(timeout: 5),
            "Selecting a result should populate the field with the chosen code"
        )
        attachScreenshot(named: "S4-ResultSelected-FieldPopulated", app: app)

        app.buttons[ID.saveContinue].tap()
        // GAP (FR7/S4): only the code is persisted (`GearCatch.statisticalArea: String?`); no
        // coordinates are stored against the catch record — see `GearCatch.swift`.
        XCTAssertTrue(
            element(app, "CatchRecord.addSpecies.heading").waitForExistence(timeout: 5),
            "Saving a valid sub-area should proceed to the next step of the journey"
        )
        attachScreenshot(named: "S4-SavedAndContinued", app: app)
    }

    /// Evidence-capture walkthrough, part 3 (S5) — an invalid code shows an inline validation
    /// error and does not route on. Fresh launch so it doesn't inherit any state from other tests.
    @MainActor
    func test_statisticalSubArea_otherOption_evidenceWalkthrough_invalidCode() {
        let app = launch()
        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        typeSearch(app, "ZZ")
        app.buttons[ID.saveContinue].tap()
        // GAP (FR8/S5): the ticket specifies the error "Enter a valid statistical sub area code.";
        // this build shows the shared "Select the area where most of your catch was caught"
        // message instead (`catchRecord.catchLocation.validation.none`, applied via
        // `CatchLocationValidation` — same rule as the map screen).
        let error = app.staticTexts["Select the area where most of your catch was caught"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), "An invalid code should surface an inline validation error")
        XCTAssertTrue(element(app, ID.heading).exists, "The user should remain on the manual-entry screen")
        attachScreenshot(named: "S5-InvalidCode-ErrorShown", app: app)
    }
}
