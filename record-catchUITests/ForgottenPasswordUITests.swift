//
//  ForgottenPasswordUITests.swift
//  record-catchUITests
//
//  Journey tests for the self-service password-reset flow (ADR-0027): "Reset your password" →
//  "Enter your reset code" → "Create a new password" → "Your password has been reset" → back to
//  Sign In. Driven by `UITestStubPasswordResetter`'s reserved `example.com` values (see
//  `FakePasswordResetter.swift`) via the `-uiTestAuthStub` seam, which also forces the
//  `FakeAuthenticator` stub so neither dependency ever touches a real Entra tenant.
//

import XCTest

final class ForgottenPasswordUITests: XCTestCase {

    private enum ID {
        static let forgottenLink = "SignIn.forgottenPasswordLink"
        static let signInHeading = "SignIn.heading"

        static let resetHeading = "PasswordReset.heading"
        static let emailField = "PasswordReset.emailField"
        static let emailError = "PasswordReset.emailError"
        static let formError = "PasswordReset.formError"
        static let sendCodeButton = "PasswordReset.sendCodeButton"

        static let enterCodeHeading = "PasswordReset.enterCode.heading"
        static let codeField = "PasswordReset.codeField"
        static let codeError = "PasswordReset.codeError"
        static let enterCodeFormError = "PasswordReset.enterCode.formError"
        static let continueButton = "PasswordReset.continueButton"
        static let sendNewCodeButton = "PasswordReset.sendNewCodeButton"

        static let createPasswordHeading = "PasswordReset.createPassword.heading"
        static let newPasswordField = "PasswordReset.newPasswordField"
        static let confirmPasswordField = "PasswordReset.confirmPasswordField"
        static let confirmPasswordError = "PasswordReset.confirmPasswordError"
        static let createPasswordFormError = "PasswordReset.createPassword.formError"
        static let savePasswordButton = "PasswordReset.savePasswordButton"

        static let completeHeading = "PasswordReset.complete.heading"
        static let completeSignInButton = "PasswordReset.complete.signInButton"

        static let offlineAuthPanel = "OfflineAuthPanel"
        static let offlineAuthPanelSignIn = "OfflineAuthPanel.signInButton"
    }

    /// Reserved `UITestStubPasswordResetter` values (see `FakePasswordResetter.swift`) —
    /// deliberately not real addresses/codes/passwords.
    private enum Stub {
        static let validEmail = "skipper@example.com"
        static let serviceErrorEmail = "error@example.com"
        static let invalidCode = "11111111"
        static let expiredCode = "22222222"
        static let weakPassword = "TestWeakPassword1!"
        static let strongPassword = "TestStrongPassw0rd!"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Launches with the deterministic auth + password-reset stubs (ADR-0022 §10 / ADR-0027 §2),
    /// then opens the "Reset your password" screen via Sign In's "Forgotten your password?" link.
    private func launchAtResetPasswordScreen() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestAuthStub"]
        app.forwardReferenceDataAPIToken()
        app.launch()

        let forgotten = app.buttons[ID.forgottenLink]
        XCTAssertTrue(forgotten.waitForExistence(timeout: 5))
        forgotten.tap()

        XCTAssertTrue(app.staticTexts[ID.resetHeading].waitForExistence(timeout: 5))
        return app
    }

    /// Drives "Reset your password" → "Enter your reset code" with a valid, unreserved email and
    /// code, landing on "Create a new password".
    private func launchAtCreatePasswordScreen() -> XCUIApplication {
        let app = launchAtResetPasswordScreen()

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()

        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))
        let code = app.textFields.firstMatch
        code.tap()
        code.typeText("ABCD1234")
        app.buttons[ID.continueButton].tap()

        XCTAssertTrue(app.staticTexts[ID.createPasswordHeading].waitForExistence(timeout: 5))
        return app
    }

    // MARK: - AC1: Reset your password screen

    @MainActor
    func test_resetPasswordScreen_showsExpectedElements() {
        let app = launchAtResetPasswordScreen()

        XCTAssertTrue(element(app, ID.emailField).exists)
        XCTAssertTrue(app.buttons[ID.sendCodeButton].exists)
    }

    // MARK: - AC2: validation

    @MainActor
    func test_resetPasswordScreen_emptyEmail_showsValidationError_andStaysOnScreen() {
        let app = launchAtResetPasswordScreen()

        app.buttons[ID.sendCodeButton].tap()

        XCTAssertTrue(element(app, ID.emailError).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[ID.resetHeading].exists)
    }

    // MARK: - AC3/AC5: valid email always proceeds (never reveals account existence)

    @MainActor
    func test_resetPasswordScreen_validEmail_navigatesToEnterCodeScreen() {
        let app = launchAtResetPasswordScreen()

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()

        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))
    }

    // MARK: - AC19: service error surfaces a generic, retryable error

    @MainActor
    func test_resetPasswordScreen_serviceError_showsGenericError_andStaysOnScreen() {
        let app = launchAtResetPasswordScreen()

        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.serviceErrorEmail)
        app.buttons[ID.sendCodeButton].tap()

        XCTAssertTrue(element(app, ID.formError).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[ID.resetHeading].exists)
    }

    // MARK: - AC6: invalid reset code

    @MainActor
    func test_enterCodeScreen_emptyCode_showsValidationError() {
        let app = launchAtResetPasswordScreen()
        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()
        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))

        app.buttons[ID.continueButton].tap()

        XCTAssertTrue(element(app, ID.codeError).waitForExistence(timeout: 5))
    }

    @MainActor
    func test_enterCodeScreen_invalidCode_showsError_andStaysOnScreen() {
        let app = launchAtResetPasswordScreen()
        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()
        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))

        let code = app.textFields.firstMatch
        code.tap()
        code.typeText(Stub.invalidCode)
        app.buttons[ID.continueButton].tap()

        XCTAssertTrue(element(app, ID.enterCodeFormError).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].exists)
    }

    // MARK: - AC7: expired reset code

    @MainActor
    func test_enterCodeScreen_expiredCode_showsExpiredError() {
        let app = launchAtResetPasswordScreen()
        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()
        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))

        let code = app.textFields.firstMatch
        code.tap()
        code.typeText(Stub.expiredCode)
        app.buttons[ID.continueButton].tap()

        let error = element(app, ID.enterCodeFormError)
        XCTAssertTrue(error.waitForExistence(timeout: 5))
    }

    // MARK: - AC8: valid code proceeds to Create a new password

    @MainActor
    func test_enterCodeScreen_validCode_navigatesToCreatePasswordScreen() {
        _ = launchAtCreatePasswordScreen()
    }

    // MARK: - AC9: "Send a new code" restarts the journey with a blank email

    @MainActor
    func test_enterCodeScreen_sendNewCode_returnsToResetPasswordScreen_withBlankEmail() {
        let app = launchAtResetPasswordScreen()
        let email = app.textFields.firstMatch
        email.tap()
        email.typeText(Stub.validEmail)
        app.buttons[ID.sendCodeButton].tap()
        XCTAssertTrue(app.staticTexts[ID.enterCodeHeading].waitForExistence(timeout: 5))

        app.buttons[ID.sendNewCodeButton].tap()

        XCTAssertTrue(app.staticTexts[ID.resetHeading].waitForExistence(timeout: 5))
        let restartedEmail = app.textFields.firstMatch
        XCTAssertTrue(restartedEmail.waitForExistence(timeout: 5))
        // `NavigationStack` rebuilds asynchronously after the path is replaced — wait for the
        // value to settle rather than asserting against a single snapshot.
        let isBlank = NSPredicate { _, _ in (restartedEmail.value as? String ?? "").isEmpty }
        wait(for: [expectation(for: isBlank, evaluatedWith: restartedEmail)], timeout: 5)
    }

    // MARK: - AC13/AC14/AC15: new password validation

    @MainActor
    func test_createPasswordScreen_mismatchedPasswords_showsError() {
        let app = launchAtCreatePasswordScreen()

        let newPassword = app.secureTextFields[ID.newPasswordField]
        newPassword.tap()
        newPassword.typeText(Stub.strongPassword)

        let confirmPassword = app.secureTextFields[ID.confirmPasswordField]
        confirmPassword.tap()
        confirmPassword.typeText("SomethingElse1!")

        app.buttons[ID.savePasswordButton].tap()

        XCTAssertTrue(element(app, ID.confirmPasswordError).waitForExistence(timeout: 5))
    }

    // MARK: - AC16: server-side policy rejection (passes client-side checks, rejected by Entra)

    @MainActor
    func test_createPasswordScreen_weakPassword_showsPolicyError_andStaysOnScreen() {
        let app = launchAtCreatePasswordScreen()

        let newPassword = app.secureTextFields[ID.newPasswordField]
        newPassword.tap()
        newPassword.typeText(Stub.weakPassword)

        let confirmPassword = app.secureTextFields[ID.confirmPasswordField]
        confirmPassword.tap()
        confirmPassword.typeText(Stub.weakPassword)

        app.buttons[ID.savePasswordButton].tap()

        XCTAssertTrue(element(app, ID.createPasswordFormError).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[ID.createPasswordHeading].exists)
    }

    // MARK: - ADR-0027 §9 deviation #2: text Show/Hide toggle (not the usual eye icon)

    @MainActor
    func test_createPasswordScreen_showHideToggle_changesLabel() {
        let app = launchAtCreatePasswordScreen()

        // Matched by its accessibility label (English default locale) rather than
        // `ID.secureToggle`/`ID.secureInput`: a caller-supplied `.accessibilityIdentifier(...)`
        // on the whole `TextInputField` instance (as `CreateNewPasswordView` applies, to give
        // each field a screen-unique identifier) takes over the identifier of the field's own
        // inner accessibility element, so the shared `TextInputField.secureToggle` constant
        // cannot be relied on once a screen has more than one secure field.
        let toggle = app.buttons["Show password"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        toggle.tap()

        XCTAssertTrue(app.buttons["Hide password"].firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - AC16/AC17: successful reset, then back to Sign In (no auto sign-in, ADR-0027 §4)

    @MainActor
    func test_createPasswordScreen_validPassword_navigatesToCompleteScreen_thenReturnsToSignIn() {
        let app = launchAtCreatePasswordScreen()

        let newPassword = app.secureTextFields[ID.newPasswordField]
        newPassword.tap()
        newPassword.typeText(Stub.strongPassword)

        let confirmPassword = app.secureTextFields[ID.confirmPasswordField]
        confirmPassword.tap()
        confirmPassword.typeText(Stub.strongPassword)

        app.buttons[ID.savePasswordButton].tap()

        XCTAssertTrue(app.staticTexts[ID.completeHeading].waitForExistence(timeout: 5))

        app.buttons[ID.completeSignInButton].tap()

        XCTAssertTrue(
            app.staticTexts[ID.signInHeading].waitForExistence(timeout: 5),
            "Completing the reset must return to Sign In rather than signing the user in automatically"
        )
    }

    // MARK: - AC18: offline during the journey

    @MainActor
    func test_offlineAuthPanel_onSignIn_showsExpectedElements_andSignInButtonIsTappable() {
        // Offline is detected at launch (ADR-0027 §7) — the panel covers Sign In immediately, so
        // this never reaches "Forgotten your password?"; it exercises the same panel shown
        // throughout the reset journey (`SignInFlowView` presents it regardless of the pushed
        // route). The panel is bound to the (test-fixed) connectivity state, not a dismissible
        // sheet, so — matching a real device, where the user only taps "Sign in" after
        // reconnecting — it remains on screen for the lifetime of this forced-offline launch;
        // this test confirms its content and that the button is safely tappable (it cancels any
        // in-flight reset state), not that tapping alone can end the device's offline state.
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestResetLanguage", "-uiTestAuthStub", "-uiTestOffline"]
        app.forwardReferenceDataAPIToken()
        app.launch()

        let panel = element(app, ID.offlineAuthPanel)
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["OfflineAuthPanel.title"].exists)
        XCTAssertTrue(app.staticTexts["OfflineAuthPanel.message"].exists)

        app.buttons[ID.offlineAuthPanelSignIn].tap()

        // Still offline, so the panel is still the only thing on screen — confirms the tap
        // didn't crash or leave the app in an unexpected state.
        XCTAssertTrue(panel.exists)
    }
}
