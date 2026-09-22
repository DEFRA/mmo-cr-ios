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
        static let createRecord = "Home.createRecordButton"

        static let draftGroup = "CatchRecord.draftAction.radioGroup"
        static let draftComplete = "CatchRecord.draftAction.option.complete"
        static let draftDelete = "CatchRecord.draftAction.option.delete"
        static let draftContinue = "CatchRecord.draftAction.saveContinue"
        static let draftError = "CatchRecord.draftAction.error"
        static let draftDeleteConfirm = "CatchRecord.draftAction.deleteConfirm"
        static let draftDeleteCancel = "CatchRecord.draftAction.deleteCancel"

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
        static let departurePicker = "CatchRecord.tripDate.departure.picker"
        static let returnHeading = "CatchRecord.tripDate.return.heading"
        static let returnContinue = "CatchRecord.tripDate.return.saveContinue"
        static let returnPicker = "CatchRecord.tripDate.return.picker"

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

        // Creates a real Unsent draft within this test's own launch session (rather than relying
        // on a draft left over from another test): starts a new catch record and picks a vessel,
        // which persists an Unsent draft as soon as `draft.vessel` is set (see
        // `CatchRecordHostView`'s `onChange(of: router.path)`). UI tests use an in-memory
        // `ModelContainer` (see `LaunchArguments.isUITesting`), so this draft is scoped to this
        // process only and never leaks into — or depends on — any other test.
        let createButton = app.buttons[ID.createRecord]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let achilles = element(app, ID.vesselAchilles)
        XCTAssertTrue(achilles.waitForExistence(timeout: 5))
        achilles.tap()
        app.buttons[ID.vesselContinue].tap()

        // Reached "Did your trip start and finish today?" — the vessel selection is now persisted.
        XCTAssertTrue(element(app, ID.tripGroup).waitForExistence(timeout: 5))

        // Navigate back to Home (Trip today → Select vessel → Home), so Home reloads its merged
        // records list (see `HomeView`'s `onChange(of: router.path)`) and picks up the new draft.
        let backButton = element(app, "ViewHeader.backButton")
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(element(app, ID.vesselGroup).waitForExistence(timeout: 5))
        backButton.tap()

        // Back at Home: the new draft sorts first (most recently edited — see `RecordsMerging`),
        // so it's the first row.
        let dateLink = element(app, "Home.table.row.0.date")
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

        // Departure date screen. The native `DatePicker` (see `TripDatePicker`, ADR-0017)
        // defaults to today and is range-constrained rather than validated, so accepting the
        // default on both screens is itself a valid "no dates entered" journey — a return date of
        // "today" never falls outside the 24-hour submission window and triggers the Submission
        // Nudge screen (see `SubmissionNudge`).
        XCTAssertTrue(element(app, ID.departureHeading).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.departurePicker).exists)
        app.buttons[ID.departureContinue].tap()

        // Return date screen.
        XCTAssertTrue(element(app, ID.returnHeading).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.returnPicker).exists)
        app.buttons[ID.returnContinue].tap()

        // With no favourites yet, enters the port sub-journey at the Add-port screen.
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))
    }

    // MARK: - Port journey

    @MainActor
    func test_portJourney_addFirstPort_thenSelectDepartureAndReturn_reachesGearSubJourney() {
        let app = launch("-uiTestCatchRecordAddPort")

        // Add-port screen shown first (no favourites yet).
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))

        // Submitting with no selection shows the inline error and does not route — still on the
        // Add-port screen (no container-level identifier on the search field itself: see
        // `AddPortView`'s comment on why one isn't applied there).
        app.buttons["CatchRecord.addPort.saveContinue"].tap()
        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").exists)

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

        // Lands on "Was Newlyn your departure and return port?" — answering "No" continues into
        // the separate departure/return select screens as before.
        app.buttons["CatchRecord.addPort.saveContinue"].tap()
        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").waitForExistence(timeout: 5))
        element(app, "CatchRecord.confirmSamePort.option.no").tap()
        app.buttons["CatchRecord.confirmSamePort.saveContinue"].tap()

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

    // MARK: - Confirm same port (Was `<port>` your departure and return port?)

    @MainActor
    func test_confirmSamePort_submitWithNoSelection_showsInlineError() {
        let app = launch("-uiTestCatchRecordConfirmSamePort")

        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").waitForExistence(timeout: 5))
        app.buttons["CatchRecord.confirmSamePort.saveContinue"].tap()

        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.error").waitForExistence(timeout: 5))
        // Did not route on: still on the confirm screen.
        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").exists)
    }

    @MainActor
    func test_confirmSamePort_yes_bypassesSelectPortScreens_reachesGearSubJourneyDirectly() {
        let app = launch("-uiTestCatchRecordConfirmSamePort")

        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").waitForExistence(timeout: 5))
        element(app, "CatchRecord.confirmSamePort.option.yes").tap()
        app.buttons["CatchRecord.confirmSamePort.saveContinue"].tap()

        // Skips both "Which port did you leave from?"/"Which port did you return to?" screens and
        // lands straight in the gear sub-journey (no favourite gears seeded → Add-gear screen).
        XCTAssertTrue(element(app, "CatchRecord.addGear.heading").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "CatchRecord.selectPort.departure.heading").exists)
        XCTAssertFalse(element(app, "CatchRecord.selectPort.return.heading").exists)
    }

    @MainActor
    func test_confirmSamePort_no_continuesToSelectPortDeparture() {
        let app = launch("-uiTestCatchRecordConfirmSamePort")

        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").waitForExistence(timeout: 5))
        element(app, "CatchRecord.confirmSamePort.option.no").tap()
        app.buttons["CatchRecord.confirmSamePort.saveContinue"].tap()

        XCTAssertTrue(element(app, "CatchRecord.selectPort.departure.heading").waitForExistence(timeout: 5))
    }

    @MainActor
    func test_confirmSamePort_addAnotherPort_returnsToAddPortSearch() {
        let app = launch("-uiTestCatchRecordConfirmSamePort")

        XCTAssertTrue(element(app, "CatchRecord.confirmSamePort.heading").waitForExistence(timeout: 5))
        app.buttons["CatchRecord.confirmSamePort.addAnother"].tap()

        XCTAssertTrue(element(app, "CatchRecord.addPort.heading").waitForExistence(timeout: 5))
    }

    // MARK: - Check your answers

    @MainActor
    func test_checkYourAnswers_showsHeadingAndAllSections() {
        let app = launch("-uiTestCatchRecordCheckYourAnswers")

        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.heading").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.trip").exists)
        XCTAssertTrue(element(app, "CatchRecord.checkYourAnswers.section.gear.SX").exists)
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

    // MARK: - Select gear — variable (per-trip) measurement conditional reveal

    private enum GearID {
        static let heading = "CatchRecord.selectGear.heading"
        static let option = "CatchRecord.selectGear.option.sx"
        static let timesShotField = "CatchRecord.selectGear.variable.sx.timesShot"
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

    @MainActor
    func test_selectGear_withDecimalVariableMeasurement_doesNotNavigate() {
        let app = launch("-uiTestCatchRecordSelectGear")

        let option = element(app, GearID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()

        let field = app.textFields[GearID.timesShotField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("5.5")

        element(app, GearID.heading).tap()
        app.buttons[GearID.saveContinue].tap()

        XCTAssertTrue(element(app, GearID.heading).exists)
        XCTAssertFalse(element(app, GearID.catchLocationHeading).exists)
    }

    // MARK: - Remove species

    private enum RemoveSpeciesID {
        static let removeLink = "CatchRecord.recordSpeciesWeights.removeSpecies"
        static let heading = "CatchRecord.removeSpecies.heading"
        static let codOption = "CatchRecord.removeSpecies.option.atlantic cod (cod)"
        static let bassOption = "CatchRecord.removeSpecies.option.seabass (bss)"
        static let delete = "CatchRecord.removeSpecies.delete"
        static let cancel = "CatchRecord.removeSpecies.cancel"
        static let error = "CatchRecord.removeSpecies.error"
        static let confirmDelete = "CatchRecord.removeSpecies.confirmDelete"
        static let cancelDeleteConfirm = "CatchRecord.removeSpecies.cancelDeleteConfirm"
        static let weightsHeading = "CatchRecord.recordSpeciesWeights.heading"
        static let addSpeciesHeading = "CatchRecord.addSpecies.heading"
    }

    @MainActor
    func test_recordSpeciesWeights_withRecordedSpecies_showsRemoveLink_navigatingToRemoveSpecies() {
        let app = launch("-uiTestCatchRecordRecordSpeciesWeights")

        let removeLink = app.buttons[RemoveSpeciesID.removeLink]
        XCTAssertTrue(removeLink.waitForExistence(timeout: 5))
        removeLink.tap()

        XCTAssertTrue(element(app, RemoveSpeciesID.heading).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_removeSpecies_cancel_returnsToWeightsScreenWithNoChanges() {
        let app = launch("-uiTestCatchRecordRecordSpeciesWeights")

        app.buttons[RemoveSpeciesID.removeLink].tap()
        XCTAssertTrue(element(app, RemoveSpeciesID.heading).waitForExistence(timeout: 5))

        app.buttons[RemoveSpeciesID.cancel].tap()

        XCTAssertTrue(element(app, RemoveSpeciesID.weightsHeading).waitForExistence(timeout: 5))
        // The link that was tapped to get here still shows — nothing was removed.
        XCTAssertTrue(app.buttons[RemoveSpeciesID.removeLink].exists)
    }

    @MainActor
    func test_removeSpecies_deleteWithNoSelection_showsInlineError() {
        let app = launch("-uiTestCatchRecordRemoveSpecies")

        let deleteButton = app.buttons[RemoveSpeciesID.delete]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertTrue(element(app, RemoveSpeciesID.error).waitForExistence(timeout: 5))
        // Did not present the confirmation dialog.
        XCTAssertFalse(element(app, RemoveSpeciesID.confirmDelete).exists)
    }

    @MainActor
    func test_removeSpecies_removingOneOfTwo_returnsToWeightsScreen() {
        let app = launch("-uiTestCatchRecordRemoveSpecies")

        let codOption = element(app, RemoveSpeciesID.codOption)
        XCTAssertTrue(codOption.waitForExistence(timeout: 5))
        codOption.tap()
        app.buttons[RemoveSpeciesID.delete].tap()

        let confirmButton = element(app, RemoveSpeciesID.confirmDelete)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // A species remains for this gear, so the journey returns to the weights screen.
        XCTAssertTrue(element(app, RemoveSpeciesID.weightsHeading).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_removeSpecies_removingLastOne_routesToAddSpecies() {
        let app = launch("-uiTestCatchRecordRemoveSpecies")

        let codOption = element(app, RemoveSpeciesID.codOption)
        let bassOption = element(app, RemoveSpeciesID.bassOption)
        XCTAssertTrue(codOption.waitForExistence(timeout: 5))
        codOption.tap()
        bassOption.tap()
        app.buttons[RemoveSpeciesID.delete].tap()

        let confirmButton = element(app, RemoveSpeciesID.confirmDelete)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Deleting the last recorded species routes onward to Add-species rather than back to the
        // now-empty weights screen.
        XCTAssertTrue(element(app, RemoveSpeciesID.addSpeciesHeading).waitForExistence(timeout: 5))
    }
}
