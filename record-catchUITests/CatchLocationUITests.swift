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
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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
        let app = launch()

        // Select a gear and enter its required per-trip measurement, then continue — the same one
        // real step the existing gear test uses to reach the catch-location map.
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

        // The catch-location map screen opens.
        XCTAssertTrue(
            element(app, CatchLocationID.heading).waitForExistence(timeout: 5),
            "Continuing from select gear should open the catch-location map heading"
        )
        XCTAssertTrue(element(app, CatchLocationID.map).exists, "The offline map should be present on the screen")
        XCTAssertTrue(element(app, CatchLocationID.saveContinue).exists, "Save and continue should be reachable")
    }
}
