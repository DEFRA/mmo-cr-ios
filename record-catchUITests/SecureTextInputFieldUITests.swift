//
//  SecureTextInputFieldUITests.swift
//  record-catchUITests
//
//  Verifies the security-relevant show/hide behaviour of the secure
//  `TextInputField` via its stable accessibility identifiers.
//

import XCTest

final class SecureTextInputFieldUITests: XCTestCase {

    private enum Identifier {
        static let secureInput = "TextInputField.secureInput"
        static let secureToggle = "TextInputField.secureToggle"
    }

    private enum ToggleLabel {
        static let show = "Show password"
        static let hide = "Hide password"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testToggleFlipsAccessibilityLabelAndFieldVisibility() throws {
        let app = XCUIApplication()
        app.launch()

        let toggle = app.buttons[Identifier.secureToggle]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Secure toggle should be present")

        // Masked by default: toggle offers to "Show password" and the field is
        // exposed as a SecureField (no plain TextField with the identifier).
        XCTAssertEqual(toggle.label, ToggleLabel.show)
        let maskedField = app.secureTextFields[Identifier.secureInput]
        XCTAssertTrue(maskedField.waitForExistence(timeout: 5), "Field should be masked (SecureField) initially")

        maskedField.tap()
        maskedField.typeText("hunter2")

        // Reveal: toggle now offers to "Hide password" and the field becomes a
        // plain, visible TextField.
        toggle.tap()
        XCTAssertEqual(toggle.label, ToggleLabel.hide)
        let visibleField = app.textFields[Identifier.secureInput]
        XCTAssertTrue(visibleField.waitForExistence(timeout: 5), "Field should be visible (TextField) after reveal")
        XCTAssertEqual(visibleField.value as? String, "hunter2")

        // Hide again: label flips back and the field re-masks.
        toggle.tap()
        XCTAssertEqual(toggle.label, ToggleLabel.show)
        XCTAssertTrue(
            app.secureTextFields[Identifier.secureInput].waitForExistence(timeout: 5),
            "Field should be masked again after hiding"
        )
    }
}
