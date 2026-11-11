//
//  PasswordResetErrorMapping.swift
//  record-catch
//
//  Pure classification of password-reset failures (ADR-0027 §§3/5/6), kept free of any MSAL type
//  so it is fully unit-testable without the SDK. `MSALNativePasswordResetter` (excluded from
//  coverage per ADR-0016 §4, mirroring `MSALNativeAuthenticator`) translates real MSAL errors into
//  the plain `ResetErrorInfo` input this file consumes, then calls these pure functions.
//

import Foundation

/// A flattened, MSAL-free description of one reset-flow failure, built by the MSAL adapter from
/// whichever concrete MSAL error type it received. Every property defaults to `false`/empty so a
/// caller only sets what's relevant to the specific error it's describing.
struct ResetErrorInfo: Equatable {
    var isUserNotFound = false
    var isInvalidUsername = false
    var isUserDoesNotHavePassword = false
    var isInvalidCode = false
    var isInvalidPassword = false
    var isBrowserRequired = false
    var errorCodes: [Int] = []

    /// AADSTS error codes (numeric family ~552003 per Microsoft's native authentication API
    /// reference) that indicate an expired continuation token/code (ADR-0027 §5).
    static let expiredTokenErrorCodes: Set<Int> = [552_003, 70_002, 90_010]

    var isExpiredToken: Bool {
        !Set(errorCodes).isDisjoint(with: Self.expiredTokenErrorCodes)
    }
}

enum PasswordResetErrorMapping {

    /// Maps a `/resetpassword/start` failure to a request outcome. Every account-existence-
    /// revealing case collapses to `.codeSent` (ADR-0027 §3, security-critical, 100%-covered).
    static func requestCodeOutcome(for error: ResetErrorInfo) -> ResetCodeRequestOutcome {
        if error.isUserNotFound || error.isInvalidUsername || error.isUserDoesNotHavePassword {
            return .codeSent
        }
        if error.isBrowserRequired {
            return .serviceUnavailable
        }
        return .serviceUnavailable
    }

    /// Maps a code-verification failure. `requestedAt`/`now` back the local expiry fallback
    /// (ADR-0027 §5) for the case where MSAL doesn't surface a recognisable expired-token code.
    static func verifyCodeOutcome(
        for error: ResetErrorInfo,
        requestedAt: Date,
        now: Date = .now
    ) -> ResetCodeVerificationOutcome {
        if error.isBrowserRequired {
            return .serviceUnavailable
        }
        if error.isExpiredToken {
            return .expired
        }
        if error.isInvalidCode {
            let elapsed = now.timeIntervalSince(requestedAt)
            return elapsed >= PasswordResetConfiguration.codeLifetime ? .expired : .invalidCode
        }
        return .serviceUnavailable
    }

    /// Maps a new-password submission failure.
    static func submitPasswordOutcome(for error: ResetErrorInfo) -> NewPasswordOutcome {
        if error.isBrowserRequired {
            return .serviceUnavailable
        }
        if error.isExpiredToken {
            return .sessionExpired
        }
        if error.isInvalidPassword {
            return .doesNotMeetPolicy
        }
        return .serviceUnavailable
    }
}
