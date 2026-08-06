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
        static let email = "SignIn.emailField"
        // NOTE: There is no `SignIn.passwordField` identifier. `TextInputField` is a
        // composite and an outer identifier is swallowed by the inner secure input,
        // so the password field is addressed via `TextInputField.secureInput`.
        static let signIn = "SignIn.signInButton"
        static let emailError = "SignIn.emailError"
        static let passwordError = "SignIn.passwordError"
        static let credentialError = "SignIn.credentialError"
        static let forgotten = "SignIn.forgottenPasswordLink"
        static let createAccount = "SignIn.createAccountLink"
        static let trouble = "SignIn.troubleHeading"
        static let languageToggle = "Header.languageToggle"
        static let secureInput = "TextInputField.secureInput"
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
    func test_emptySubmit_showsBothInlineErrors_thenClearOnInput() {
        let app = XCUIApplication()
        app.launch()

        app.buttons[ID.signIn].tap()

        XCTAssertTrue(element(app, ID.emailError).waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, ID.passwordError).exists)

        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("skipper@example.com")

        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("hunter2")

        XCTAssertFalse(element(app, ID.emailError).exists)
        XCTAssertFalse(element(app, ID.passwordError).exists)
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
    func test_credentialError_appearsOnStubbedSubmit_thenClearsOnEdit() {
        let app = XCUIApplication()
        app.launch()

        // Type a valid-shaped email + password so field validation passes and the
        // stubbed credential error path is taken on submit.
        let email = app.textFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("skipper@example.com")

        let password = app.secureTextFields[ID.secureInput]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("hunter2")

        app.buttons[ID.signIn].tap()

        // Stubbed credential-error summary should appear.
        XCTAssertTrue(
            element(app, ID.credentialError).waitForExistence(timeout: 5),
            "Credential error summary should appear after a filled (stubbed) submit"
        )

        // Editing a field clears the credential error.
        email.tap()
        email.typeText("x")

        XCTAssertFalse(
            element(app, ID.credentialError).exists,
            "Credential error should clear after editing a field"
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
