//
//  XCUIApplication+ReferenceDataToken.swift
//  record-catchUITests
//
//  Relays the DEBUG-only reference-data API bearer token into the app under test (see ADR-0018
//  §5 and `AuthTokenProviding.swift`'s `EnvironmentTokenProvider`).
//
//  In a local Xcode run, Xcode's own scheme environment variables (Product ▸ Scheme ▸ Edit
//  Scheme… ▸ Test) are already inherited by the launched app, so this is a no-op belt-and-braces
//  step there. It matters on BrowserStack App Automate: BrowserStack's `setEnvVariables` build
//  parameter only reaches the *XCUITest runner process* (this test target), not the application
//  under test — so without this explicit relay, every UI test run against BrowserStack would send
//  no bearer token and reference-data calls would fail with `APIError.unauthorized`.
//

import XCTest

extension XCUIApplication {

    /// Copies `REFERENCE_DATA_API_TOKEN` from this test runner's process environment into the
    /// launched app's `launchEnvironment`, when present. Call before `launch()`. A missing value
    /// leaves `launchEnvironment` untouched, matching `EnvironmentTokenProvider`'s existing
    /// "no token set" behaviour (requests are sent without an `Authorization` header).
    func forwardReferenceDataAPIToken() {
        guard let token = ProcessInfo.processInfo.environment["REFERENCE_DATA_API_TOKEN"] else { return }
        launchEnvironment["REFERENCE_DATA_API_TOKEN"] = token
    }
}
