//
//  SubmissionNudgeUITests.swift
//  record-catchUITests
//
//  Journey tests for the late-submission nudge screen shown when a trip ended more than 24 hours
//  ago (records must be submitted within 24 hours). Seeded straight to the screen via the
//  `-uiTestCatchRecordSubmissionNudge` launch seam (see `UITestRootView`), so the late date does
//  not have to be computed by hand.
//

import XCTest

final class SubmissionNudgeUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.submissionNudge.heading"
        static let referenceNumber = "CatchRecord.submissionNudge.referenceNumber"
        static let saveContinue = "CatchRecord.submissionNudge.saveContinue"
        static let checkDateLink = "CatchRecord.submissionNudge.checkDateLink"

        static let addPortHeading = "CatchRecord.addPort.heading"
        static let homeWarningBox = "Home.warningBox"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestCatchRecordSubmissionNudge"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_submissionNudge_showsHeadingAndReferenceNumber() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.referenceNumber).exists)
        XCTAssertTrue(element(app, ID.checkDateLink).exists)
    }

    @MainActor
    func test_submissionNudge_saveAndContinue_entersPortSubJourney() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        app.buttons[ID.saveContinue].tap()

        // Acknowledging the nudge continues into the port sub-journey (no favourite ports seeded →
        // the Add-port screen).
        XCTAssertTrue(element(app, ID.addPortHeading).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_submissionNudge_checkTripEndDateLink_popsBack() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        element(app, ID.checkDateLink).tap()

        // Pops back off the nudge screen (the seam pushes only this screen, so it returns to Home).
        XCTAssertTrue(element(app, ID.homeWarningBox).waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, ID.heading).exists)
    }
}
