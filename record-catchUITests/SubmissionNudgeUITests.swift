//
//  SubmissionNudgeUITests.swift
//  record-catchUITests
//
//  Journey tests for the late-submission nudge screen shown directly before "Check your catch
//  record" when a trip ended more than 24 hours ago (records must be submitted within 24 hours).
//  Seeded straight to the screen via the `-uiTestCatchRecordSubmissionNudge` launch seam (see
//  `UITestRootView`), so the late date does not have to be computed by hand.
//

import XCTest

final class SubmissionNudgeUITests: XCTestCase {

    private enum ID {
        static let heading = "CatchRecord.submissionNudge.heading"
        static let referenceNumber = "CatchRecord.submissionNudge.referenceNumber"
        static let saveContinue = "CatchRecord.submissionNudge.saveContinue"
        static let checkDateLink = "CatchRecord.submissionNudge.checkDateLink"

        static let checkYourAnswersHeading = "CatchRecord.checkYourAnswers.heading"
        static let returnDateHeading = "CatchRecord.tripDate.return.heading"
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
    func test_submissionNudge_saveAndContinue_goesToCheckYourCatchRecord() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        app.buttons[ID.saveContinue].tap()

        // "Save and continue" goes straight to "Check your catch record" — the nudge no longer
        // interposes the port sub-journey (see ADR-0003 amendment, plan Q10).
        XCTAssertTrue(element(app, ID.checkYourAnswersHeading).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_submissionNudge_checkTripEndDateLink_opensReturnDateScreen() {
        let app = launch()

        XCTAssertTrue(element(app, ID.heading).waitForExistence(timeout: 5))
        element(app, ID.checkDateLink).tap()

        // Opens the return-date screen in "Change" mode so the date can be corrected — submitting
        // there re-runs the late-submission check (see `TripDateViewModel.submit()`).
        XCTAssertTrue(element(app, ID.returnDateHeading).waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, ID.heading).exists)
    }
}
