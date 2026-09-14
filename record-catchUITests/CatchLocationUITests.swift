//
//  CatchLocationUITests.swift
//  record-catchUITests
//
//  Journey test for the "Where was most of your catch caught?" map screen, hosted via the
//  deterministic `-uiTestCatchLocation` launch seam (see `UITestRootView`). That seam boots
//  straight to the map for a new catch record with a departure port that carries a REAL
//  coordinate, so the map's port-framing (see `PortMapCamera`) is exercised without signing in or
//  driving the whole journey by hand. Exhaustive framing logic is covered by `PortMapCameraTests`
//  and `CatchLocationViewModelTests`; this is the in-app smoke test that the screen actually opens.
//

import XCTest

final class CatchLocationUITests: XCTestCase {

    private enum ID {
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

    /// Launches straight into the catch-location map, resetting any Welsh language preference a
    /// prior test in the same run may have left behind (mirrors the other journey UI tests).
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchLocation"]
        app.launch()
        return app
    }

    @MainActor
    func test_catchLocationSeam_opensMapScreen_withoutSignIn() {
        let app = launch()

        // The map screen opens directly — no sign-in / journey navigation required.
        XCTAssertTrue(
            element(app, ID.heading).waitForExistence(timeout: 5),
            "The `-uiTestCatchLocation` seam should boot straight to the catch-location map heading"
        )
        XCTAssertTrue(element(app, ID.map).exists, "The offline map should be present on the screen")
        XCTAssertTrue(element(app, ID.saveContinue).exists, "Save and continue should be reachable")
    }
}
