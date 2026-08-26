//
//  ManageAccountUITests.swift
//  record-catchUITests
//
//  Journey tests for the "Manage your account" screen (see
//  docs/design-specs/manage-account.md), hosted via the `-uiTestManageAccount` launch
//  argument. Covers navigating from Settings' "My account" link, the "Your details" field
//  rows, the Face ID toggle, and returning via the shared header's Back control.
//

import XCTest

final class ManageAccountUITests: XCTestCase {

    private enum ID {
        static let title = "ManageAccount.title"
        static let changeFirstName = "ManageAccount.change.firstName"
        static let changeLastName = "ManageAccount.change.lastName"
        static let changeAddress = "ManageAccount.change.address"
        static let changeEmail = "ManageAccount.change.email"
        static let changeContactNumber = "ManageAccount.change.contactNumber"
        static let faceIDToggle = "ManageAccount.faceIDToggle"
        static let myAccountLink = "Settings.link.myAccount"
        static let backButton = "ViewHeader.backButton"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(directTo manageAccount: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage"]
        app.launchArguments += manageAccount ? ["-uiTestManageAccount"] : ["-uiTestSettings"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_manageAccountScreen_showsYourDetailsAndFaceIDSection() {
        let app = launch()

        XCTAssertTrue(app.staticTexts[ID.title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your details"].exists)
        XCTAssertTrue(app.staticTexts["James"].exists)
        XCTAssertTrue(app.staticTexts["Wilson"].exists)
        XCTAssertTrue(app.staticTexts["Harbour View House, The Quay, Peterhead, AB42 1BY"].exists)
        XCTAssertTrue(app.staticTexts["james.wilson@company.co.uk"].exists)
        XCTAssertTrue(app.staticTexts["07700 900123"].exists)

        XCTAssertTrue(app.staticTexts["Sign in"].exists)
        XCTAssertTrue(app.staticTexts["Face ID sign-in"].exists)
        XCTAssertTrue(element(app, ID.faceIDToggle).exists)
    }

    @MainActor
    func test_changeLinks_reachableAndLabelled() {
        let app = launch()

        XCTAssertTrue(element(app, ID.changeFirstName).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.changeLastName).exists)
        XCTAssertTrue(element(app, ID.changeAddress).exists)
        XCTAssertTrue(element(app, ID.changeEmail).exists)
        XCTAssertTrue(element(app, ID.changeContactNumber).exists)
    }

    @MainActor
    func test_changeFirstName_reachable_butDoesNotNavigateOrCrash() {
        let app = launch()

        let change = element(app, ID.changeFirstName)
        XCTAssertTrue(change.waitForExistence(timeout: 5))
        change.tap()

        // Inert seam: tapping "Change" has no destination yet — the screen (and its title)
        // should still be showing, with no navigation/crash.
        XCTAssertTrue(app.staticTexts[ID.title].exists, "Change is inert — Manage your account should still be showing")
    }

    @MainActor
    func test_faceIDToggle_enableAttempt_withNoBiometricsEnrolled_staysOff_andShowsAccessibleFailure() {
        // The toggle now drives a REAL biometric enrolment check (ADR-0009). The CI/simulator
        // has no biometrics enrolled by default, so turning it on must fail gracefully: the
        // toggle stays off (never a silent "looks enabled but isn't") and an accessible
        // failure message appears — it must never crash or dead-end the user.
        let app = launch()

        let toggle = element(app, ID.faceIDToggle)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "Toggle should start off (-uiTestManageAccount resets the preference)")

        toggle.tap()

        let failureMessage = element(app, "ManageAccount.faceIDEnableFailed")
        XCTAssertTrue(failureMessage.waitForExistence(timeout: 5), "Failed biometric check should surface an accessible error")
        XCTAssertEqual(toggle.value as? String, "0", "Toggle must not flip on when the biometric check fails")
    }

    @MainActor
    func test_tabBar_staysVisible_onManageAccount() {
        let app = launch()

        XCTAssertTrue(app.staticTexts[ID.title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Home"].isHittable, "Tab bar should remain visible on Manage your account")
        XCTAssertTrue(app.tabBars.buttons["Settings"].isHittable)
    }

    @MainActor
    func test_navigateFromSettings_myAccountLink_pushesManageAccount() {
        let app = launch(directTo: false)

        let myAccount = element(app, ID.myAccountLink)
        XCTAssertTrue(myAccount.waitForExistence(timeout: 5))
        myAccount.tap()

        XCTAssertTrue(app.staticTexts[ID.title].waitForExistence(timeout: 5))
    }

    @MainActor
    func test_backButton_returnsToSettings() {
        let app = launch()

        XCTAssertTrue(app.staticTexts[ID.title].waitForExistence(timeout: 5))

        let backButton = element(app, ID.backButton)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }
}
