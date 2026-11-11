//
//  PasswordResetConfiguration.swift
//  record-catch
//
//  Pure constants for the password-reset journey (ADR-0027 §5/§6). No I/O.
//

import Foundation

enum PasswordResetConfiguration {
    /// Defensive local fallback for AC8 ("expired reset code"): if a code-verification failure
    /// happens this long after the code was requested, it is treated as expired even if MSAL
    /// didn't report a recognisable expired-token error code (ADR-0027 §5). The real, Entra-side
    /// code lifetime shown in the design ("5 minutes") must be confirmed with the Entra tenant
    /// team; this value is deliberately a little longer so it only ever acts as a backstop, never
    /// pre-empting a genuine still-valid code.
    static let codeLifetime: TimeInterval = 6 * 60

    /// Minimum new-password length (ADR-0027 §6 / Entra's combined password policy).
    static let minimumPasswordLength = 8
    /// Maximum new-password length (Entra's combined password policy).
    static let maximumPasswordLength = 256
    /// Minimum number of distinct character classes (upper/lower/number/symbol) a new password
    /// must contain (Entra's combined password policy: "3 of 4").
    static let minimumCharacterClasses = 3
}
