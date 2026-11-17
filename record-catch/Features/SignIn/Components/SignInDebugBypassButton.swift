//
//  SignInDebugBypassButton.swift
//  record-catch
//
//  TEMP SIGN-IN BYPASS — remove. Temporary developer shortcut that skips Entra sign-in by calling
//  the normal `onSignIn` path with a placeholder account. Compiled into Debug AND Release builds at
//  developer instruction, but hidden in the Prod app (`mmo.catchrecording.ios`) so it can never
//  reach the App Store (the Prod external N.1 upload is the App Store build — ADR-0021).
//  Excluded from coverage in sonar-project.properties. Flagged security deviation
//  (security.instructions.md: "No ... debug backdoors in release builds").
//

import SwiftUI
import os

extension AuthenticatedAccount {
    /// TEMP SIGN-IN BYPASS — placeholder account. Holds no real identity or credentials.
    static let debugBypass = AuthenticatedAccount(username: "debug-bypass", identifier: "debug-bypass")
}

/// TEMP SIGN-IN BYPASS — decides whether the bypass button may be shown.
enum SignInDebugBypass {
    static let prodBundleIdentifier = "mmo.catchrecording.ios"

    /// `false` for the Prod app (all Prod TestFlight builds and the App Store); `true` otherwise.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != prodBundleIdentifier
    }
}

/// TEMP SIGN-IN BYPASS — "Skip sign in" button for the Sign In screen.
struct SignInDebugBypassButton: View {
    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "signIn")

    let onSignIn: (AuthenticatedAccount) -> Void

    var body: some View {
        if SignInDebugBypass.isAvailable {
            SecondaryButton(title: "Skip sign in (temporary)") {
                Self.logger.notice("Sign-in bypassed via temporary bypass button")
                onSignIn(.debugBypass)
            }
            .accessibilityLabel("Skip sign in, temporary testing shortcut")
            .accessibilityIdentifier("SignIn.debugBypassButton")
        }
    }
}
