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
//  is the in-app smoke test that the map screen actually opens and is reachable; tapping a
//  subrectangle submits and routes on immediately — there is no separate "Save and continue"
//  button on this screen (see `CatchLocationView`).
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

    /// Attaches a full-screen screenshot to the test as QA evidence, kept even on a passing run
    /// so it's retrievable from the resulting `.xcresult` bundle.
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    /// `XCUIElement.pinch(withScale:velocity:)` returns as soon as the synthetic touches lift, but
    /// `MKMapView` keeps animating its camera (spring/deceleration) for a short time afterwards —
    /// there's no XCUITest-visible signal (no accessibility value, no animation-idle predicate) to
    /// wait on directly, so this settles on a fixed pause. Without it, `attachScreenshot` captures
    /// a part-way animation frame, not the fully zoomed state.
    private func waitForZoomGestureToSettle() {
        Thread.sleep(forTimeInterval: 1.0)
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
        app.forwardReferenceDataAPIToken()
        app.launch()
        return app
    }

    @MainActor
    func test_selectGearToCatchLocation_opensMapScreen() {
        let app = reachCatchLocationMap()

        // The catch-location map screen opens with the interactive map, ready for the user to tap
        // a subrectangle to select it (FR2) — there is no separate "Save and continue" button.
        XCTAssertTrue(element(app, CatchLocationID.map).exists, "The offline map should be present on the screen")
        XCTAssertTrue(element(app, CatchLocationID.otherButton).exists, "The manual \"Other\" entry point should be reachable")
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

    /// Confirms the interactive map loads with its accessibility identifier and is on-screen and
    /// hittable, independent of the zoom-gesture tests below.
    @MainActor
    func test_catchLocationMap_loadsWithInteractiveMapElement() {
        let app = reachCatchLocationMap()

        let map = element(app, CatchLocationID.map)
        XCTAssertTrue(map.waitForExistence(timeout: 5), "The offline map should load with its accessibility identifier")
        XCTAssertTrue(map.isHittable, "The offline map should be visible and interactive on screen")
    }

    /// Pinch-zooms out on the map (see `OfflineMapView.minZoomDistance`/`maxZoomDistance` for the
    /// native MapKit zoom limits this gesture is bounded by) and confirms the map stays valid,
    /// visible and responsive throughout, and that a subsequent, unrelated interaction ("Other")
    /// still works — i.e. the zoom gesture doesn't leave the screen unresponsive.
    ///
    /// NOTE on the screenshots this test attaches as QA evidence: `XCUIElement.pinch(withScale:
    /// velocity:)` synthesises touches on a "best effort" basis (Apple's own documentation says
    /// accuracy isn't guaranteed), and empirically — captured and diffed against this map's
    /// `minZoomDistance`/`maxZoomDistance` bounds during investigation — a single synthetic pinch
    /// does not reliably move `MKMapView`'s camera in the Simulator, so "Default" and "After" can
    /// legitimately look the same. These assertions therefore verify *behavioural* responsiveness
    /// (the map/screen stay interactive and navigation still works), not a specific zoom-level
    /// change — treat the attached screenshots as "screen after the gesture was sent" evidence,
    /// not proof the zoom level changed.
    @MainActor
    func test_catchLocationMap_pinchToZoomOut_mapRemainsResponsive() {
        let app = reachCatchLocationMap()

        let map = element(app, CatchLocationID.map)
        XCTAssertTrue(map.waitForExistence(timeout: 5), "The map should be present before zooming")
        XCTAssertTrue(map.isHittable, "The map should be interactive before zooming")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-Default-3x3", app: app)

        map.pinch(withScale: 0.5, velocity: -1.0)

        XCTAssertTrue(map.exists, "The map should remain valid immediately after a zoom-out gesture")
        XCTAssertTrue(map.isHittable, "The map should remain visible and interactive after a zoom-out gesture")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-After-PinchZoomOut", app: app)

        let other = element(app, CatchLocationID.otherButton)
        XCTAssertTrue(other.waitForExistence(timeout: 5), "The \"Other\" control should still be reachable after zooming out")
        other.tap()
        XCTAssertTrue(
            element(app, ManualEntryID.heading).waitForExistence(timeout: 5),
            "Navigation should still work normally after a zoom-out gesture"
        )
    }

    /// Pinch-zooms in on the map and confirms the same responsiveness, then that navigation still
    /// functions afterwards via the "Other" entry point (mirrors the zoom-out test above) — there
    /// is no "Save and continue" button to re-exercise on this screen.
    @MainActor
    func test_catchLocationMap_pinchToZoomIn_mapRemainsResponsive() {
        let app = reachCatchLocationMap()

        let map = element(app, CatchLocationID.map)
        XCTAssertTrue(map.waitForExistence(timeout: 5), "The map should be present before zooming")
        XCTAssertTrue(map.isHittable, "The map should be interactive before zooming")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-Default-3x3", app: app)

        map.pinch(withScale: 2.0, velocity: 1.0)

        XCTAssertTrue(map.exists, "The map should remain valid immediately after a zoom-in gesture")
        XCTAssertTrue(map.isHittable, "The map should remain visible and interactive after a zoom-in gesture")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-After-PinchZoomIn", app: app)

        let other = element(app, CatchLocationID.otherButton)
        XCTAssertTrue(other.waitForExistence(timeout: 5), "The \"Other\" control should still be reachable after a zoom-in gesture")
        other.tap()
        XCTAssertTrue(
            element(app, ManualEntryID.heading).waitForExistence(timeout: 5),
            "Navigation should still work normally after a zoom-in gesture"
        )
    }

    /// Chains a zoom out then a zoom in on the same map instance, confirming it survives repeated
    /// gestures back-to-back without becoming stale, invisible or unresponsive.
    @MainActor
    func test_catchLocationMap_pinchZoomOutThenIn_mapRemainsResponsive() {
        let app = reachCatchLocationMap()

        let map = element(app, CatchLocationID.map)
        XCTAssertTrue(map.waitForExistence(timeout: 5), "The map should be present before zooming")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-Default-3x3", app: app)

        map.pinch(withScale: 0.5, velocity: -1.0)
        XCTAssertTrue(map.exists, "The map should remain valid after zooming out")
        XCTAssertTrue(map.isHittable, "The map should remain interactive after zooming out")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-After-PinchZoomOut", app: app)

        map.pinch(withScale: 2.0, velocity: 1.0)
        XCTAssertTrue(map.exists, "The map should remain valid after zooming back in")
        XCTAssertTrue(map.isHittable, "The map should remain interactive after zooming back in")
        waitForZoomGestureToSettle()
        attachScreenshot(named: "CatchLocation-Map-After-PinchZoomIn", app: app)

        // Tap the "Other" control and confirm it still actually functions (rather than just
        // checking `isHittable`, which can be reported before the simulator settles after two
        // gestures fired back-to-back) — reaching the manual-entry heading proves the whole
        // screen, not just the map, is still genuinely responsive.
        let other = element(app, CatchLocationID.otherButton)
        XCTAssertTrue(other.waitForExistence(timeout: 5), "The \"Other\" control should still be reachable after repeated zoom gestures")
        other.tap()
        XCTAssertTrue(
            element(app, ManualEntryID.heading).waitForExistence(timeout: 5),
            "Navigation should still work normally after repeated zoom gestures"
        )
    }
}
