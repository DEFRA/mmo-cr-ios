//
//  HomeUITests.swift
//  record-catchUITests
//
//  Journey test for the UI-only Home / "Your trips" screen, hosted via the
//  `-uiTestHome` launch argument and driven by accessibility identifiers.
//

import XCTest

final class HomeUITests: XCTestCase {

    private enum ID {
        static let warningBox = "Home.warningBox"
        static let paginationPrevious = "Home.pagination.previous"
        static let paginationNext = "Home.pagination.next"
        static let paginationPage1 = "Home.pagination.page.1"
        static let createRecord = "Home.createRecordButton"
        static let firstRowDate = "Home.table.row.0.date"
        static let howToRecord = "Home.howToRecord"
        static let statusHelp = "Home.statusHelp"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestHome"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_homeScreen_showsExpectedElements() {
        let app = launchHome()

        XCTAssertTrue(element(app, ID.warningBox).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[ID.createRecord].exists)

        // First table row date link (driven by a stable identifier, not a
        // language-specific accessibility label).
        let firstDateLink = element(app, ID.firstRowDate)
        XCTAssertTrue(firstDateLink.exists)
    }

    @MainActor
    func test_pagination_singlePage_showsPageOneAndRangeHidesPreviousNext() {
        let app = launchHome()

        XCTAssertTrue(element(app, ID.paginationPage1).waitForExistence(timeout: 5))

        // Single page: Previous and Next are hidden.
        XCTAssertFalse(element(app, ID.paginationPrevious).exists)
        XCTAssertFalse(element(app, ID.paginationNext).exists)

        XCTAssertTrue(app.staticTexts["Showing 1 to 4 of 4"].exists)
    }

    @MainActor
    func test_createRecordButton_startsNewCatchRecordJourney() {
        let app = launchHome()

        let button = app.buttons[ID.createRecord]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        // No longer inert: routes straight to Select vessel.
        let selectVesselHeading = element(app, "CatchRecord.selectVessel.radioGroup")
        XCTAssertTrue(selectVesselHeading.waitForExistence(timeout: 5))
    }

    @MainActor
    func test_howToRecordSection_isCollapsedByDefaultAndExpandsOnTap() {
        let app = launchHome()

        let disclosure = element(app, ID.howToRecord)
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))

        // Collapsed by default: sub-heading content is not yet on screen.
        XCTAssertFalse(app.staticTexts["What you need to do"].exists)

        disclosure.tap()

        XCTAssertTrue(app.staticTexts["What you need to do"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["When to create your record"].exists)
        XCTAssertTrue(app.staticTexts["Special cases: ICES areas"].exists)
        XCTAssertTrue(app.staticTexts["Get help with your record"].exists)
    }

    @MainActor
    func test_howToRecordAndStatusHelpSections_expandIndependently() {
        let app = launchHome()

        let howToRecord = element(app, ID.howToRecord)
        let statusHelp = element(app, ID.statusHelp)
        XCTAssertTrue(howToRecord.waitForExistence(timeout: 5))
        XCTAssertTrue(statusHelp.exists)

        statusHelp.tap()

        XCTAssertTrue(app.staticTexts["Unsent:"].waitForExistence(timeout: 5))
        // Expanding the status-help section doesn't also reveal How to record.
        XCTAssertFalse(app.staticTexts["What you need to do"].exists)
    }
}
