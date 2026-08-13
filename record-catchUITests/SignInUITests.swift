//
//  SignInUITests.swift
//  record-catchUITests
//
//  Journey test for the UI-only Sign In screen driven by accessibility identifiers.
//

import XCTest

final class SignInUITests: XCTestCase {

    private enum ID {
        static let heading = "SignIn.heading"
        // NOTE: There is no `SignIn.passwordField` identifier. `TextInputField` is a
        // composite and an outer identifier is swallowed by the inner secure input,
        // so the password field is addressed via `TextInputField.secureInput`.
        static let signIn = "SignIn.signInButton"
        static let forgotten = "SignIn.forgottenPasswordLink"
        static let createAccount = "SignIn.createAccountLink"
        static let trouble = "SignIn.troubleHeading"
        static let languageToggle = "Header.languageToggle"
        static let secureInput = "TextInputField.secureInput"
        static let homeCreateRecord = "Home.createRecordButton"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Finds an element by accessibility identifier regardless of its exposed type.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_signInScreen_showsExpectedElements() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts[ID.heading].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[ID.signIn].exists)
        XCTAssertTrue(app.staticTexts[ID.trouble].exists)
        XCTAssertTrue(app.buttons[ID.forgotten].exists)
        XCTAssertTrue(app.buttons[ID.createAccount].exists)
    }

    @MainActor
    func test_signInButton_navigatesToHome_withEmptyForm() {
        // DEMO-ONLY BYPASS: no real auth exists yet, so tapping "Sign in" always
        // succeeds and continues to Home regardless of what's in the form.
        let app = XCUIApplication()
        app.launch()

        app.buttons[ID.signIn].tap()

        XCTAssertTrue(
            element(app, ID.homeCreateRecord).waitForExistence(timeout: 5),
            "Tapping Sign in should navigate to Home even with an empty form"
        )
    }

    @MainActor
    func test_languageToggle_changesVisibleCopy() {
        let app = XCUIApplication()
        app.launch()

        let heading = app.staticTexts[ID.heading]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, "Sign in")

        app.buttons[ID.languageToggle].tap()

        // Welsh copy for the heading.
        XCTAssertTrue(
            app.staticTexts["Mewngofnodi"].waitForExistence(timeout: 5),
            "Heading should switch to Welsh copy after toggling language"
        )
    }

    @MainActor
    func test_signInButton_navigatesToHome_withFilledForm() {
        let app = XCUIApplication()
        app.launch()

        // Type a valid-shaped email + password to demonstrate the form still
        // accepts input, but the sign-in bypass ignores it either way.
        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("skipper@example.com")

        let password = app.secureTextFields[ID.secureInput]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("hunter2")

        app.buttons[ID.signIn].tap()

        XCTAssertTrue(
            element(app, ID.homeCreateRecord).waitForExistence(timeout: 5),
            "Tapping Sign in should navigate to Home with a filled form"
        )
    }

    @MainActor
    func test_helpLinks_existAndAreInert() {
        let app = XCUIApplication()
        app.launch()

        let forgotten = app.buttons[ID.forgotten]
        XCTAssertTrue(forgotten.waitForExistence(timeout: 5))
        forgotten.tap()

        // Inert: still on the Sign In screen after tapping.
        XCTAssertTrue(app.staticTexts[ID.heading].exists)
        XCTAssertTrue(app.buttons[ID.createAccount].exists)
    }
}
