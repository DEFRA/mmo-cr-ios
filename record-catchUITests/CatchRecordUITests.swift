//
//  CatchRecordUITests.swift
//  record-catchUITests
//
//  Journey tests for Part 1 of "Create a catch record" (Draft action → Select vessel →
//  Did your trip start and finish today?), driven by accessibility identifiers.
//

import XCTest

final class CatchRecordUITests: XCTestCase {

    private enum ID {
        static let firstRowDate = "Home.table.row.0.date" // Submitted row — inert
        static let unsentRowDate = "Home.table.row.2.date" // Unsent (draft) row
        static let createRecord = "Home.createRecordButton"

        static let draftGroup = "CatchRecord.draftAction.radioGroup"
        static let draftComplete = "CatchRecord.draftAction.option.complete"
        static let draftDelete = "CatchRecord.draftAction.option.delete"
        static let draftContinue = "CatchRecord.draftAction.saveContinue"
        static let draftError = "CatchRecord.draftAction.error"
        static let draftDeleteConfirm = "CatchRecord.draftAction.deleteConfirm"

        static let vesselGroup = "CatchRecord.selectVessel.radioGroup"
        static let vesselAchilles = "CatchRecord.selectVessel.option.achilles"
        static let vesselContinue = "CatchRecord.selectVessel.saveContinue"
        static let vesselError = "CatchRecord.selectVessel.error"

        static let tripGroup = "CatchRecord.tripToday.radioGroup"
        static let tripYes = "CatchRecord.tripToday.option.yes"
        static let tripNo = "CatchRecord.tripToday.option.no"
        static let tripContinue = "CatchRecord.tripToday.saveContinue"
        static let tripError = "CatchRecord.tripToday.error"
        static let tripReference = "CatchRecord.tripToday.referenceNumber"

        static let departureHeading = "CatchRecord.tripDate.departure.heading"
        static let departureContinue = "CatchRecord.tripDate.departure.saveContinue"
        static let departureError = "CatchRecord.tripDate.departure.error"
        static let returnHeading = "CatchRecord.tripDate.return.heading"
        static let returnContinue = "CatchRecord.tripDate.return.saveContinue"

        static let warningBox = "Home.warningBox"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ argument: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", argument]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Draft journey (Home → draft row → Draft action)

    @MainActor
    func test_homeUnsentRow_opensDraftAction() {
        let app = launch("-uiTestHome")

        let dateLink = element(app, ID.unsentRowDate)
        XCTAssertTrue(dateLink.waitForExistence(timeout: 5))
        dateLink.tap()

        XCTAssertTrue(element(app, ID.draftGroup).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_draftAction_submitWithNoSelection_showsInlineError() {
        let app = launch("-uiTestCatchRecordDraft")

        let continueButton = app.buttons[ID.draftContinue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(element(app, ID.draftError).waitForExistence(timeout: 5))
        // Did not route on: still showing the radio group.
        XCTAssertTrue(element(app, ID.draftGroup).exists)
    }

    @MainActor
    func test_draftAction_delete_continue_confirm_returnsToHome() {
        let app = launch("-uiTestCatchRecordDraft")

        let deleteOption = element(app, ID.draftDelete)
        XCTAssertTrue(deleteOption.waitForExistence(timeout: 5))
        deleteOption.tap()

        app.buttons[ID.draftContinue].tap()

        let confirmButton = element(app, ID.draftDeleteConfirm)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Back at Home.
        XCTAssertTrue(element(app, ID.warningBox).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_draftAction_complete_continue_routesToSelectVessel() {
        let app = launch("-uiTestCatchRecordDraft")

        let completeOption = element(app, ID.draftComplete)
        XCTAssertTrue(completeOption.waitForExistence(timeout: 5))
        completeOption.tap()

        app.buttons[ID.draftContinue].tap()

        XCTAssertTrue(element(app, ID.vesselGroup).waitForExistence(timeout: 5))
    }

    // MARK: - New journey (Home → create → Select vessel → Trip today)

    @MainActor
    func test_homeCreateRecordButton_opensSelectVessel() {
        let app = launch("-uiTestHome")

        let createButton = app.buttons[ID.createRecord]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        XCTAssertTrue(element(app, ID.vesselGroup).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_selectVessel_submitWithNoSelection_showsInlineError() {
        let app = launch("-uiTestCatchRecordNew")

        let continueButton = app.buttons[ID.vesselContinue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(element(app, ID.vesselError).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_fullNewJourney_selectVessel_tripTodayYes_reachesAddPort() {
        let app = launch("-uiTestCatchRecordNew")

        let achilles = element(app, ID.vesselAchilles)
        XCTAssertTrue(achilles.waitForExistence(timeout: 5))
        achilles.tap()
        app.buttons[ID.vesselContinue].tap()

        XCTAssertTrue(element(app, ID.tripGroup).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.tripReference).exists)

        // Submit with no selection first shows the inline error and doesn't route.
        app.buttons[ID.tripContinue].tap()
        XCTAssertTrue(element(app, ID.tripError).waitForExistence(timeout: 5))

        // Select Yes and continue — with no favourites yet, enters the port sub-journey at Add port.
        element(app, ID.tripYes).tap()
        app.buttons[ID.tripContinue].tap()

        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))
    }

    @MainActor
    func test_tripToday_no_routesThroughDepartureAndReturn_toAddPort() {
        let app = launch("-uiTestCatchRecordNew")

        // Select vessel → Trip today.
        let achilles = element(app, ID.vesselAchilles)
        XCTAssertTrue(achilles.waitForExistence(timeout: 5))
        achilles.tap()
        app.buttons[ID.vesselContinue].tap()

        // Trip today → No.
        XCTAssertTrue(element(app, ID.tripNo).waitForExistence(timeout: 5))
        element(app, ID.tripNo).tap()
        app.buttons[ID.tripContinue].tap()

        // Departure date screen. Dates are computed relative to "now" (rather than a fixed
        // historical date) so a return date of "today" never falls outside the 24-hour
        // submission window and triggers the Submission Nudge screen (see `SubmissionNudge`).
        let departure = dateStrings(daysAgo: 1)
        let returnValue = dateStrings(daysAgo: 0)

        XCTAssertTrue(element(app, ID.departureHeading).waitForExistence(timeout: 5))
        enterDate(app, day: departure.day, month: departure.month, year: departure.year, headingID: ID.departureHeading)
        app.buttons[ID.departureContinue].tap()

        // Return date screen.
        XCTAssertTrue(element(app, ID.returnHeading).waitForExistence(timeout: 5))
        enterDate(app, day: returnValue.day, month: returnValue.month, year: returnValue.year, headingID: ID.returnHeading)
        app.buttons[ID.returnContinue].tap()

        // With no favourites yet, enters the port sub-journey at the Add-port screen.
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))
    }

    @MainActor
    func test_tripDate_departure_submitWithNoDate_showsInlineError() {
        let app = launch("-uiTestCatchRecordNew")

        let achilles = element(app, ID.vesselAchilles)
        XCTAssertTrue(achilles.waitForExistence(timeout: 5))
        achilles.tap()
        app.buttons[ID.vesselContinue].tap()

        XCTAssertTrue(element(app, ID.tripNo).waitForExistence(timeout: 5))
        element(app, ID.tripNo).tap()
        app.buttons[ID.tripContinue].tap()

        XCTAssertTrue(element(app, ID.departureHeading).waitForExistence(timeout: 5))
        app.buttons[ID.departureContinue].tap()

        XCTAssertTrue(element(app, ID.departureError).waitForExistence(timeout: 5))
        // Did not route on: still on the departure screen.
        XCTAssertTrue(element(app, ID.departureHeading).exists)
    }

    // MARK: - Port journey

    @MainActor
    func test_portJourney_addFirstPort_thenSelectDepartureAndReturn_reachesGearSubJourney() {
        let app = launch("-uiTestCatchRecordAddPort")

        // Add-port screen shown first (no favourites yet).
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))

        // Submitting with no selection shows the inline error and does not route.
        app.buttons["CatchRecord.addPort.saveContinue"].tap()
        XCTAssertTrue(element(app, "CatchRecord.addPort.search").exists)

        // Type a port and pick it from the results. "Newlyn" is a real entry in
        // `StubPortOptionProvider`'s list — the previous "Hastings" never matched any port, so
        // the results list never actually rendered and the test's "successful" tap was silently
        // landing on the search `TextField` instead (its value happens to equal the typed text).
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Newlyn")
        // Queried by the result row's own stable identifier, not its label text: without one, a
        // broad `.any`-type query for the label can also resolve to the `TextField` above once
        // its typed value matches the same text, silently mistapping it instead of the row.
        let newlynResult = element(app, "SearchDropdownField.result.Newlyn")
        XCTAssertTrue(newlynResult.waitForExistence(timeout: 5))
        newlynResult.tap()

        // Lands on the departure select screen with the new favourite present.
        app.buttons["CatchRecord.addPort.saveContinue"].tap()
        XCTAssertTrue(element(app, "CatchRecord.selectPort.departure.heading").waitForExistence(timeout: 5))
        app.buttons["CatchRecord.selectPort.departure.saveContinue"].tap()
        // No selection → inline error.
        XCTAssertTrue(element(app, "CatchRecord.selectPort.departure.error").waitForExistence(timeout: 5))

        element(app, "CatchRecord.selectPort.departure.option.newlyn").tap()
        app.buttons["CatchRecord.selectPort.departure.saveContinue"].tap()

        // Return select screen.
        XCTAssertTrue(element(app, "CatchRecord.selectPort.return.heading").waitForExistence(timeout: 5))
        element(app, "CatchRecord.selectPort.return.option.newlyn").tap()
        app.buttons["CatchRecord.selectPort.return.saveContinue"].tap()

        // With no favourite gears yet, enters the gear sub-journey at the Add-gear screen.
        XCTAssertTrue(element(app, "CatchRecord.addGear.heading").waitForExistence(timeout: 5))
    }

    @MainActor
    func test_portJourney_withSeededFavourites_startsAtSelectDeparture_andAddAnotherReturnsToSearch() {
        let app = launch("-uiTestCatchRecordSelectPort")

        // With favourites seeded, the departure select screen is shown first.
        XCTAssertTrue(element(app, "CatchRecord.selectPort.departure.heading").waitForExistence(timeout: 5))

        // "Add another port" routes to the Add-port search screen.
        app.buttons["CatchRecord.selectPort.departure.addAnother"].tap()
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))
    }

    // MARK: - Check your answers

    @MainActor
    func test_checkYourAnswers_showsHeadingAndAllFourSections() {
        let app = launch("-uiTestCatchRecordCheckYourAnswers")

        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.heading").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.trip").exists)
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.gear").exists)
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.speciesCaught").exists)
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.speciesNotLanded").exists)
    }

    @MainActor
    func test_checkYourAnswers_showsExpectedSeededValues() {
        let app = launch("-uiTestCatchRecordCheckYourAnswers")

        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.heading").waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["ACHILLES"].exists)
        XCTAssertTrue(app.staticTexts["Plymouth"].exists)
        XCTAssertTrue(app.staticTexts["27.7.e"].exists)
        XCTAssertTrue(app.staticTexts["Seine nets (not specified)"].exists)
        XCTAssertTrue(app.staticTexts["80"].exists)
        XCTAssertTrue(app.staticTexts["Atlantic cod (COD)"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["250 kg"].exists)
        XCTAssertTrue(app.staticTexts["5 kg"].exists)
    }

    @MainActor
    func test_checkYourAnswers_tappingChange_navigatesAwayFromSummary() {
        let app = launch("-uiTestCatchRecordCheckYourAnswers")

        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.heading").waitForExistence(timeout: 5))

        let changeVessel = app.buttons["CatchRecord.checkYourAnswers.change.trip.vessel"]
        XCTAssertTrue(changeVessel.waitForExistence(timeout: 5))
        changeVessel.tap()

        // Navigates forward into the journey, to the screen the vessel was captured on.
        XCTAssertTrue(element(app, ID.vesselGroup).waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "CatchRecord.checkYourAnswers.heading").exists)
    }

    @MainActor
    func test_checkYourAnswers_tappingSaveAndContinue_navigatesToSubmissionConfirmation() {
        let app = launch("-uiTestCatchRecordCheckYourAnswers")

        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.heading").waitForExistence(timeout: 5))

        let saveContinue = app.buttons["CatchRecord.checkYourAnswers.saveContinue"]
        XCTAssertTrue(saveContinue.waitForExistence(timeout: 5))
        saveContinue.tap()

        XCTAssertTrue(element(app, "CatchRecord.submissionConfirmation.heading").waitForExistence(timeout: 5))
    }

    // MARK: - Submission confirmation

    @MainActor
    func test_submissionConfirmation_acceptWithNoTick_showsInlineError_andDoesNotRoute() {
        let app = launch("-uiTestCatchRecordSubmissionConfirmation")

        XCTAssertTrue(element(app, "CatchRecord.submissionConfirmation.heading").waitForExistence(timeout: 5))

        app.buttons["CatchRecord.submissionConfirmation.accept"].tap()

        XCTAssertTrue(element(app, "CatchRecord.submissionConfirmation.error").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "CatchRecord.submissionConfirmation.heading").exists)
    }

    @MainActor
    func test_submissionConfirmation_tickingCheckboxThenAccept_navigatesToSubmissionSuccess() {
        let app = launch("-uiTestCatchRecordSubmissionConfirmation")

        XCTAssertTrue(element(app, "CatchRecord.submissionConfirmation.heading").waitForExistence(timeout: 5))

        element(app, "CatchRecord.submissionConfirmation.confirmCheckbox").tap()
        app.buttons["CatchRecord.submissionConfirmation.accept"].tap()

        XCTAssertTrue(element(app, "CatchRecord.submissionSuccess.panel").waitForExistence(timeout: 10))
    }

    // MARK: - Submission success

    @MainActor
    func test_submissionSuccess_showsConfirmationPanelAndWhatHappensNext() {
        let app = launch("-uiTestCatchRecordSubmissionSuccess")

        XCTAssertTrue(element(app, "CatchRecord.submissionSuccess.panel").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "CatchRecord.submissionSuccess.whatHappensNextHeading").exists)
        XCTAssertTrue(element(app, "CatchRecord.submissionSuccess.bulletList").exists)
    }

    @MainActor
    func test_submissionSuccess_tappingViewCatchRecords_returnsToHome() {
        let app = launch("-uiTestCatchRecordSubmissionSuccess")

        let viewRecords = app.buttons["CatchRecord.submissionSuccess.viewRecords"]
        XCTAssertTrue(viewRecords.waitForExistence(timeout: 5))
        viewRecords.tap()

        // Back at Home.
        XCTAssertTrue(element(app, ID.warningBox).waitForExistence(timeout: 5))
    }

    /// Day/month/year components for a date `daysAgo` days before "now", zero-padded for the
    /// date-entry fields. Used instead of a fixed historical date so trip-date UI tests stay
    /// deterministic regardless of when they're run (see `SubmissionNudge.isNeeded`, which compares
    /// against the real wall clock in the running app).
    private func dateStrings(daysAgo: Int) -> (day: String, month: String, year: String) {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        return (
            String(format: "%02d", components.day ?? 1),
            String(format: "%02d", components.month ?? 1),
            String(format: "%04d", components.year ?? 2020)
        )
    }

    private func enterDate(_ app: XCUIApplication, day: String, month: String, year: String, headingID: String) {
        let dayField = app.textFields["Day"]
        XCTAssertTrue(dayField.waitForExistence(timeout: 5))
        dayField.tap()
        dayField.typeText(day)

        let monthField = app.textFields["Month"]
        monthField.tap()
        monthField.typeText(month)

        let yearField = app.textFields["Year"]
        yearField.tap()
        yearField.typeText(year)

        // Dismiss the number pad (which has no return key) by tapping the screen heading,
        // which stays near the top and never scrolls the continue button out of reach.
        element(app, headingID).tap()
    }

    // MARK: - Select gear — variable (per-trip) measurement conditional reveal

    private enum GearID {
        static let heading = "CatchRecord.selectGear.heading"
        static let option = "CatchRecord.selectGear.option.seine nets (not specified)"
        static let timesShotField = "CatchRecord.selectGear.variable.seine nets (not specified).timesShot"
        static let saveContinue = "CatchRecord.selectGear.saveContinue"
        static let catchLocationHeading = "CatchRecord.catchLocation.heading"
    }

    @MainActor
    func test_selectGear_tickingGear_revealsVariableMeasurementField() {
        let app = launch("-uiTestCatchRecordSelectGear")

        let option = element(app, GearID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5))

        // Field is hidden until the gear is ticked (GOV.UK conditional-reveal pattern).
        XCTAssertFalse(element(app, GearID.timesShotField).exists)

        option.tap()

        XCTAssertTrue(element(app, GearID.timesShotField).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_selectGear_continueWithoutVariableMeasurement_doesNotNavigate() {
        let app = launch("-uiTestCatchRecordSelectGear")

        let option = element(app, GearID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        app.buttons[GearID.saveContinue].tap()

        // Required variable measurement is empty → stays on the gear screen.
        XCTAssertTrue(element(app, GearID.heading).exists)
        XCTAssertFalse(element(app, GearID.catchLocationHeading).exists)
    }

    @MainActor
    func test_selectGear_withValidVariableMeasurement_navigatesToCatchLocation() {
        let app = launch("-uiTestCatchRecordSelectGear")

        let option = element(app, GearID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        let field = app.textFields[GearID.timesShotField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("5")

        // Dismiss the number pad by tapping the heading, then continue.
        element(app, GearID.heading).tap()
        app.buttons[GearID.saveContinue].tap()

        XCTAssertTrue(element(app, GearID.catchLocationHeading).waitForExistence(timeout: 5))
    }
}
