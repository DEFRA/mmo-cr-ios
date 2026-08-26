//
//  AppLockUITests.swift
//  record-catchUITests
//
//  Journey tests for the offline biometric local re-entry ("app lock") screen (ADR-0009), hosted
//  via deterministic `-uiTestAppLock*` launch arguments that inject fakes — no real biometric
//  hardware is exercised (see `record_catchApp.swift`'s UI-test seams and
//  `AppLockViewModelTests`/`BiometricReentryPolicyTests` for the exhaustive logic coverage).
//

import XCTest

final class AppLockUITests: XCTestCase {

    private enum ID {
        static let heading = "AppLock.heading"
        static let unlockButton = "AppLock.unlockButton"
        static let fallbackLink = "AppLock.passwordFallbackLink"
        static let faceIDHint = "AppLock.faceIDHint"
        static let signInHeading = "SignIn.heading"
        static let homeCreateRecord = "Home.createRecordButton"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func test_eligibleReentry_showsAppLockScreen_withFaceIDCopy() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestAppLockLocked"]
        app.launch()

        XCTAssertTrue(app.staticTexts[ID.heading].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[ID.unlockButton].exists)
        XCTAssertEqual(app.buttons[ID.unlockButton].label, "Unlock with Face ID")
        XCTAssertTrue(element(app, ID.faceIDHint).exists, "Face ID scans immediately, so the pre-scan hint should show")
        XCTAssertTrue(app.buttons[ID.fallbackLink].exists, "Manual fallback must always be visible")
    }

    @MainActor
    func test_unlockButton_onSuccess_navigatesToHome() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestAppLockLocked"]
        app.launch()

        let unlock = app.buttons[ID.unlockButton]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()

        XCTAssertTrue(
            element(app, ID.homeCreateRecord).waitForExistence(timeout: 5),
            "A successful biometric re-entry should navigate straight to Home"
        )
    }

    @MainActor
    func test_manualFallbackLink_alwaysReachable_navigatesToSignIn() {
        // Never a dead end: the manual "sign in instead" path must work even while biometric
        // re-entry is being offered (accessibility.instructions.md).
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestAppLockLocked"]
        app.launch()

        let fallback = app.buttons[ID.fallbackLink]
        XCTAssertTrue(fallback.waitForExistence(timeout: 5))
        fallback.tap()

        XCTAssertTrue(
            app.staticTexts[ID.signInHeading].waitForExistence(timeout: 5),
            "The fallback link should always hand off to the normal sign-in form"
        )
    }

    @MainActor
    func test_ineligibleReentry_skipsAppLock_showsSignInDirectly() {
        // No biometrics enrolled + preference off + no secret provisioned: the app must never
        // show a stuck/broken app-lock screen — it should go straight to sign-in (ADR-0009 §1).
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestAppLockFallback"]
        app.launch()

        XCTAssertTrue(app.staticTexts[ID.signInHeading].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[ID.heading].exists, "App-lock screen should not appear when re-entry isn't eligible")
    }
}
