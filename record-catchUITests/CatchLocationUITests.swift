//
//  CatchLocationUITests.swift
//  record-catchUITests
//
//  Journey test for the "Where was most of your catch caught?" map screen. Reaches the map through
//  the EXISTING `-uiTestCatchRecordSelectGear` launch seam (see `UITestRootView`) and the one real
//  UI step that follows — select a gear, enter its per-trip measurement, tap Save and continue —
//  exactly as `CatchRecordUITests.test_selectGear_withValidVariableMeasurement_navigatesToCatchLocation`
//  does. This keeps the test purely QA/UI-test-only: it adds no app-target launch seam.
//
//  Exhaustive port-framing/coordinate logic is covered where it is actually assertable — in
//  `PortMapCameraTests` and `CatchLocationViewModelTests` (XCUITest can't assert map pixels). This
//  is the in-app smoke test that the map screen actually opens and Save and continue is reachable.
//
    
import XCTest

final class CatchLocationUITests: XCTestCase {

    private enum GearID {
        static let heading = "CatchRecord.selectGear.heading"
        static let option = "CatchRecord.selectGear.option.sx"
        static let timesShotField = "CatchRecord.selectGear.variable.sx.timesShot"
        static let saveContinue = "CatchRecord.selectGear.saveContinue"
    }

    private enum CatchLocationID {
        static let heading = "CatchRecord.catchLocation.heading"
        static let map = "CatchRecord.catchLocation.map"
        static let saveContinue = "CatchRecord.catchLocation.saveContinue"
        static let otherButton = "CatchRecord.catchLocation.otherButton"
        static let error = "CatchRecord.catchLocation.error"
    }

    private enum ManualEntryID {
        static let heading = "CatchRecord.catchLocationManualEntry.heading"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Drives the one real UI step (select gear, enter its measurement, Save and continue) that
    /// opens the catch-location map, returning once the map heading is visible. Shared by every
    /// test here so each can start from the map screen without repeating the gear steps.
    @MainActor
    private func reachCatchLocationMap() -> XCUIApplication {
        let app = launch()

        let option = element(app, GearID.option)
        XCTAssertTrue(option.waitForExistence(timeout: 5), "The select-gear seam should show the gear option")
        option.tap()

        let field = app.textFields[GearID.timesShotField]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Ticking the gear should reveal its measurement field")
        field.tap()
        field.typeText("5")

        // Dismiss the number pad (no return key) by tapping the heading, then continue.
        element(app, GearID.heading).tap()
        app.buttons[GearID.saveContinue].tap()

        XCTAssertTrue(
            element(app, CatchLocationID.heading).waitForExistence(timeout: 5),
            "Continuing from select gear should open the catch-location map heading"
        )
        return app
    }

    /// Launches at the "What gear did you use?" screen via the existing seam, resetting any Welsh
    /// language preference a prior test in the same run may have left behind (mirrors the other
    /// journey UI tests).
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordSelectGear"]
        app.launch()
        return app
    }

    @MainActor
    func test_selectGearToCatchLocation_opensMapScreen() {
        let app = reachCatchLocationMap()

        // The catch-location map screen opens with the interactive map and Save and continue (FR2).
        XCTAssertTrue(element(app, CatchLocationID.map).exists, "The offline map should be present on the screen")
        XCTAssertTrue(element(app, CatchLocationID.saveContinue).exists, "Save and continue should be reachable")
    }

    /// Scenario 5 / FR11 — "Save and continue" with no area selected must show the inline
    /// validation error and keep the user on the same screen (it must not route on).
    @MainActor
    func test_catchLocation_saveContinueWithNoSelection_showsErrorAndStays() {
        let app = reachCatchLocationMap()

        app.buttons[CatchLocationID.saveContinue].tap()

        XCTAssertTrue(
            element(app, CatchLocationID.error).waitForExistence(timeout: 5),
            "Continuing with no statistical area selected should show the inline validation error"
        )
        XCTAssertTrue(
            element(app, CatchLocationID.heading).exists,
            "The user should remain on the catch-location screen when no area is selected"
        )
        XCTAssertFalse(
            element(app, "CatchRecord.recordSpeciesWeights.heading").exists,
            "The journey must not advance to the species screen without a selected area"
        )
        XCTAssertFalse(
            element(app, "CatchRecord.addSpecies.heading").exists,
            "The journey must not advance to the add-species screen without a selected area"
        )
    }

    /// Scenario 1 / FR1 — the "Other" option navigates to the statistical sub-area selection
    /// screen where the fisher can pick an area another way (in this build, the manual
    /// type-to-search "Enter the statistical sub area…" screen).
    @MainActor
    func test_catchLocation_otherButton_navigatesToSubAreaSelection() {
        let app = reachCatchLocationMap()

        let other = element(app, CatchLocationID.otherButton)
        XCTAssertTrue(other.waitForExistence(timeout: 5), "The map should offer an \"Other\" way to select a sub area")
        other.tap()

        XCTAssertTrue(
            element(app, ManualEntryID.heading).waitForExistence(timeout: 5),
            "Choosing \"Other\" should navigate to the statistical sub-area selection screen"
        )
    }
}
