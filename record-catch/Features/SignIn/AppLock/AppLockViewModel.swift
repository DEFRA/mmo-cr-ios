//
//  AppLockViewModel.swift
//  record-catch
//
//  View model for the offline biometric local re-entry ("app lock") screen — see ADR-0009.
//  Thin: delegates every decision to the pure `BiometricReentryPolicy` helper (ADR-0001 pattern).
//

import Foundation

/// The app-lock screen's presentation state.
enum AppLockScreenState: Equatable {
    /// Working out whether to offer biometric re-entry at all.
    case checking
    /// Offering biometric re-entry; `message` is set after a retryable failed attempt.
    case locked(message: AppLockFailureMessage?)
    /// Re-entry succeeded.
    case unlocked
    /// Biometric re-entry isn't offered/available — hand off to the normal sign-in form.
    case fallbackToSignIn
}

@MainActor
@Observable
final class AppLockViewModel {

    private(set) var state: AppLockScreenState = .checking

    private let biometricAuthenticator: BiometricAuthenticating
    private let sessionStore: LocalSessionStoring
    private let secretStore: ReentrySecretStoring
    private let preferenceStore: BiometricPreferenceStoring
    private let unlockReason: String

    /// Called once biometric re-entry succeeds.
    var onUnlocked: () -> Void = {}
    /// Called whenever the flow hands off to the normal sign-in form (unavailable, locked out,
    /// or the user tapped the manual fallback link).
    var onFallbackToSignIn: () -> Void = {}

    init(
        biometricAuthenticator: BiometricAuthenticating,
        sessionStore: LocalSessionStoring,
        secretStore: ReentrySecretStoring,
        preferenceStore: BiometricPreferenceStoring,
        unlockReason: String
    ) {
        self.biometricAuthenticator = biometricAuthenticator
        self.sessionStore = sessionStore
        self.secretStore = secretStore
        self.preferenceStore = preferenceStore
        self.unlockReason = unlockReason
    }

    /// The kind of biometry available, for view copy (e.g. "Unlock with Face ID").
    var biometryKind: BiometryKind {
        if case .available(let kind) = biometricAuthenticator.biometricAvailability() {
            return kind
        }
        return .none
    }

    /// Call once when the screen appears: decides whether to offer re-entry at all.
    func evaluateOffer() {
        let offer = BiometricReentryPolicy.offer(
            hasLocalSession: sessionStore.hasLocalSession(),
            preferenceEnabled: preferenceStore.isFaceIDEnabled(),
            availability: biometricAuthenticator.biometricAvailability(),
            secretExists: secretStore.secretExists()
        )
        switch offer {
        case .offer:
            state = .locked(message: nil)
        case .fallToSignIn:
            state = .fallbackToSignIn
            onFallbackToSignIn()
        }
    }

    /// Attempts the biometric-gated re-entry.
    func authenticate() async {
        do {
            try await secretStore.verifyReentry(reason: unlockReason)
            state = .unlocked
            onUnlocked()
        } catch {
            switch BiometricReentryPolicy.nextState(afterEvaluation: .failure(error)) {
            case .unlocked:
                state = .unlocked
                onUnlocked()
            case .retry(let message):
                state = .locked(message: message)
            case .fallToSignIn:
                state = .fallbackToSignIn
                onFallbackToSignIn()
            }
        }
    }

    /// The always-available manual fallback — reachable directly regardless of biometric state,
    /// so the user is never dead-ended (see accessibility.instructions.md).
    func useSignInInstead() {
        state = .fallbackToSignIn
        onFallbackToSignIn()
    }
}
