//
//  BiometricReentryPolicy.swift
//  record-catch
//
//  Pure, stateless decision logic for the offline biometric local re-entry gate (ADR-0009). No
//  I/O — trivially unit-testable, per ADR-0001's "pure helper" pattern and this being a
//  security-critical path (100% coverage target — testing.instructions.md).
//

import Foundation

/// Whether the app should offer biometric re-entry, or go straight to the sign-in form.
enum BiometricReentryOffer: Sendable, Equatable {
    case offer
    case fallToSignIn(BiometricReentryFallbackReason)
}

enum BiometricReentryFallbackReason: Sendable, Equatable {
    case noLocalSession
    case preferenceDisabled
    case biometryUnavailable
    case secretNotProvisioned
}

/// Next app-lock screen state after a biometric evaluation attempt.
enum AppLockOutcome: Sendable, Equatable {
    case unlocked
    /// Still locked, but the user may retry biometrics (e.g. one cancelled/failed attempt).
    case retry(message: AppLockFailureMessage)
    /// Retrying would not help (lockout/unavailable) — drop straight to the sign-in form.
    case fallToSignIn(message: AppLockFailureMessage)
}

/// Perceivable (text + icon, never colour-alone — WCAG 2.2 AA) failure reason shown on the
/// app-lock screen.
enum AppLockFailureMessage: Sendable, Equatable {
    case authenticationFailed
    case biometryLockedOut
    case biometryUnavailable
    case cancelled
}

nonisolated enum BiometricReentryPolicy {

    /// Decides whether to show the app-lock (biometric re-entry) screen or go straight to the
    /// sign-in form, given the current local state. Order of checks matches ADR-0009 §1/§8.
    static func offer(
        hasLocalSession: Bool,
        preferenceEnabled: Bool,
        availability: BiometricAvailability,
        secretExists: Bool
    ) -> BiometricReentryOffer {
        guard hasLocalSession else { return .fallToSignIn(.noLocalSession) }
        guard preferenceEnabled else { return .fallToSignIn(.preferenceDisabled) }
        guard case .available = availability else { return .fallToSignIn(.biometryUnavailable) }
        guard secretExists else { return .fallToSignIn(.secretNotProvisioned) }
        return .offer
    }

    /// Maps a biometric evaluation result to the next app-lock state.
    ///
    /// Cancellation/plain authentication failure keeps the user on the lock screen so they can
    /// retry or use the always-visible manual fallback link; lockout and unavailability drop
    /// straight to sign-in since retrying biometrics would not help (ADR-0009 §4).
    static func nextState(afterEvaluation result: Result<Void, Error>) -> AppLockOutcome {
        switch result {
        case .success:
            return .unlocked
        case .failure(let error):
            guard let biometricError = error as? BiometricError else {
                return .retry(message: .authenticationFailed)
            }
            switch biometricError {
            case .biometryLockedOut:
                return .fallToSignIn(message: .biometryLockedOut)
            case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
                return .fallToSignIn(message: .biometryUnavailable)
            case .userCancelled, .systemCancelled, .userFallback:
                return .retry(message: .cancelled)
            case .authenticationFailed, .other:
                return .retry(message: .authenticationFailed)
            }
        }
    }
}
