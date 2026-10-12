//
//  OfflineBannerUITests.swift
//  record-catchUITests
//
//  Verifies the offline connectivity banner (see ADR-0019 and
//  docs/design-specs/offline-banner.md): present with the correct tag + message when the
//  `-uiTestOffline` seam forces the device offline, absent entirely when online, present across
//  more than one `ViewTemplate` screen (proving the `ViewTemplate`-level wiring, not a one-off),
//  and absent on Sign In (Q2 — Sign In / App Lock do not use `ViewTemplate` and are intentionally
//  excluded).
//

import XCTest

final class OfflineBannerUITests: XCTestCase {

    private enum ID {
        static let banner = "OfflineBanner"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(_ extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    // MARK: - Offline shows the banner

    @MainActor
    func test_banner_whenOffline_showsTagAndMessage() {
        let app = launch(["-uiTestResetLanguage", "-uiTestOffline", "-uiTestHome"])

        let banner = element(app, ID.banner)
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.hasPrefix("Offline,"))
        XCTAssertTrue(banner.label.contains("You can still record your catch"))
    }

    @MainActor
    func test_banner_whenOffline_isShownOnCatchRecordScreenToo() {
        // Proves the banner is wired into `ViewTemplate` itself (every templated screen
        // inherits it), not just hard-coded onto Home.
        let app = launch(["-uiTestResetLanguage", "-uiTestOffline", "-uiTestCatchRecordNew"])

        let banner = element(app, ID.banner)
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
    }

    // MARK: - Online shows nothing

    @MainActor
    func test_banner_whenOnline_isNotShown() {
        let app = launch(["-uiTestResetLanguage", "-uiTestHome"])

        // Give Home a moment to finish rendering before asserting absence.
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, ID.banner).exists)
    }

    // MARK: - Q2: excluded from Sign In / App Lock

    @MainActor
    func test_banner_onSignInScreen_isNotShown_evenWhenOffline() {
        // Sign In and App Lock deliberately do not use `ViewTemplate` (see
        // `SignInView.swift`/`AppLockView.swift`), so the banner must never appear there
        // regardless of connectivity — confirms the Q2 decision is actually honoured, not just
        // assumed because no code touches those screens.
        let app = launch(["-uiTestOffline"])

        XCTAssertTrue(app.staticTexts["SignIn.heading"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, ID.banner).exists)
    }
}
