//
//  PasswordResetting.swift
//  record-catch
//
//  Self-service password reset seam (ADR-0027 §2), mirroring `Authenticating` (ADR-0022 §2): the
//  password-reset view models depend only on this protocol. `MSALNativePasswordResetter` is the
//  sole real (MSAL-backed) implementation; `FakePasswordResetter`/`UITestStubPasswordResetter` are
//  in-memory doubles. No other type in the app ever imports `MSAL`.
//

import Foundation

/// Result of `requestCode(email:)` (AC2/AC3/AC9). `.codeSent` is returned for both a real and a
/// non-existent account (ADR-0027 §3, security-critical — never reveal whether an account
/// exists).
enum ResetCodeRequestOutcome: Equatable {
    case codeSent
    /// No network connectivity — the request was not attempted.
    case network
    /// Any other Entra/MSAL failure (including an unsupported step such as a browser requirement).
    case serviceUnavailable
    /// `EntraConfiguration` placeholders are not yet populated for this stage.
    case notConfigured
}

/// Result of `verifyCode(_:)` (AC6/AC7/AC8/AC10).
enum ResetCodeVerificationOutcome: Equatable {
    case verified
    /// The entered code does not match — including every attempt against a non-existent account
    /// (ADR-0027 §3), so this outcome never reveals account existence.
    case invalidCode
    /// The code (or the underlying continuation token) has expired (ADR-0027 §5, AC8).
    case expired
    case network
    case serviceUnavailable
}

/// Result of `submitNewPassword(_:)` (AC13–AC16).
enum NewPasswordOutcome: Equatable {
    case completed
    /// The password was rejected by Entra's policy (too weak, banned, recently used, or too
    /// long) — one generic outcome, since the client-side check (`PasswordResetValidation`)
    /// already catches length/character-class issues before this is ever attempted (ADR-0027 §6).
    case doesNotMeetPolicy
    /// The reset session (continuation token) is no longer valid — the user must start again
    /// from the Reset your password screen.
    case sessionExpired
    case network
    case serviceUnavailable
}

/// Self-service password reset seam (ADR-0027). A single instance carries state (MSAL's
/// continuation token) across the three steps for one in-flight reset attempt; `cancel()` drops
/// any such state, e.g. when the user chooses "Send a new code" (AC9).
@MainActor
protocol PasswordResetting: AnyObject {
    /// Starts a reset for `email` and requests a code be emailed (AC3). `email` is used as-is —
    /// callers normalise/validate first (see `PasswordResetValidation`).
    func requestCode(email: String) async -> ResetCodeRequestOutcome

    /// Validates the code entered by the user (AC6/AC7/AC8/AC10).
    func verifyCode(_ code: String) async -> ResetCodeVerificationOutcome

    /// Submits the new password once the code has been verified (AC13–AC16).
    func submitNewPassword(_ password: String) async -> NewPasswordOutcome

    /// Drops any in-flight reset state. Called when the user abandons the journey (e.g.
    /// navigating back to Sign In) or requests a new code (AC9).
    func cancel()
}
