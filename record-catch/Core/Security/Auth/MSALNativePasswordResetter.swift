//
//  MSALNativePasswordResetter.swift
//  record-catch
//
//  Wraps MSAL Native Authentication's self-service password reset (SSPR) flow (ADR-0027),
//  mirroring `MSALNativeAuthenticator`'s isolation of MSAL types (ADR-0022 §2/§9). No other type
//  in the app ever imports `MSAL`.
//
//  Passwords and codes are never stored, exposed outside this file, or logged. Account-existence-
//  revealing failures collapse to `.codeSent`/`.invalidCode` (ADR-0027 §3) via the pure, fully
//  tested `PasswordResetErrorMapping` — the detailed AADSTS codes are logged (public, non-PII)
//  for diagnostics only.
//

import Foundation
import MSAL
import os

@MainActor
final class MSALNativePasswordResetter: PasswordResetting {

    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "auth")

    private let application: MSALNativeAuthPublicClientApplication?
    private let connectivityMonitor: ConnectivityMonitoring
    private var codeRequiredState: ResetPasswordCodeRequiredState?
    private var passwordRequiredState: ResetPasswordRequiredState?
    /// When the current code was requested — backs the local expiry fallback (ADR-0027 §5).
    private var requestedAt: Date?

    /// - Parameter configuration: Already validated (ADR-0022 §6). Builds its own
    ///   `MSALNativeAuthPublicClientApplication`, independent of `MSALNativeAuthenticator`'s
    ///   (ADR-0027 §2) — if MSAL itself fails to initialise, every method below degrades to
    ///   `.serviceUnavailable`/`.sessionExpired` rather than crashing.
    init(configuration: EntraConfiguration, connectivityMonitor: ConnectivityMonitoring) {
        self.connectivityMonitor = connectivityMonitor
        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: configuration.clientID,
                tenantSubdomain: configuration.tenantSubdomain,
                // `.OOB` is required for SSPR's emailed code step, alongside the existing
                // `.password` sign-in challenge type (ADR-0027 §1, supersedes ADR-0022 §1).
                challengeTypes: [.OOB, .password]
            )
            if let bundleID = Bundle.main.bundleIdentifier {
                config.cacheConfig.keychainSharingGroup = bundleID
            }
            self.application = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
        } catch {
            Self.logger.error("Failed to initialise MSAL Native Auth application for password reset")
            self.application = nil
        }
    }

    // MARK: - Request code (AC3)

    func requestCode(email: String) async -> ResetCodeRequestOutcome {
        cancel()
        guard let application else {
            Self.logger.error("Password reset blocked: MSAL application failed to initialise")
            return .serviceUnavailable
        }
        guard connectivityMonitor.isOnline else {
            Self.logger.notice("Password reset blocked: device reports no connectivity")
            return .network
        }

        let parameters = MSALNativeAuthResetPasswordParameters(username: email)
        let delegate = ResetPasswordStartResultDelegate()
        let step = await delegate.run { application.resetPassword(parameters: parameters, delegate: $0) }

        switch step {
        case .codeRequired(let state):
            codeRequiredState = state
            requestedAt = .now
            return .codeSent
        case .failed(let error):
            return outcome(forStartError: error)
        }
    }

    private func outcome(forStartError error: ResetPasswordStartError) -> ResetCodeRequestOutcome {
        guard connectivityMonitor.isOnline else { return .network }
        let info = ResetErrorInfo(
            isUserNotFound: error.isUserNotFound,
            isInvalidUsername: error.isInvalidUsername,
            isUserDoesNotHavePassword: error.isUserDoesNotHavePassword,
            isBrowserRequired: error.isBrowserRequired,
            errorCodes: error.errorCodes
        )
        if info.isUserNotFound || info.isInvalidUsername || info.isUserDoesNotHavePassword {
            Self.logger.notice("Password reset start: account-existence-revealing failure suppressed to codeSent")
        } else {
            Self.logger.error("Password reset start failed with AADSTS codes: \(error.errorCodes, privacy: .public)")
        }
        return PasswordResetErrorMapping.requestCodeOutcome(for: info)
    }

    // MARK: - Verify code (AC6/AC7/AC8/AC10)

    func verifyCode(_ code: String) async -> ResetCodeVerificationOutcome {
        guard let application else { return .serviceUnavailable }
        // No in-flight state: either `requestCode` was never called, MSAL failed to initialise,
        // or the start request was for a non-existent account (ADR-0027 §3) — in every case the
        // code can never validate, so `.invalidCode` is the correct, non-revealing outcome.
        guard let codeRequiredState else { return .invalidCode }
        guard connectivityMonitor.isOnline else {
            Self.logger.notice("Code verification blocked: device reports no connectivity")
            return .network
        }

        let delegate = ResetPasswordVerifyCodeResultDelegate()
        let step = await delegate.run { codeRequiredState.submitCode(code: code, delegate: $0) }
        _ = application // application retained via `self`; referenced to silence unused-capture warnings only

        switch step {
        case .passwordRequired(let state):
            passwordRequiredState = state
            return .verified
        case .failed(let error, let newState):
            self.codeRequiredState = newState ?? self.codeRequiredState
            return outcome(forVerifyError: error)
        }
    }

    private func outcome(forVerifyError error: VerifyCodeError) -> ResetCodeVerificationOutcome {
        guard connectivityMonitor.isOnline else { return .network }
        let info = ResetErrorInfo(
            isInvalidCode: error.isInvalidCode,
            isBrowserRequired: error.isBrowserRequired,
            errorCodes: error.errorCodes
        )
        Self.logger.notice("Code verification failed with AADSTS codes: \(error.errorCodes, privacy: .public)")
        return PasswordResetErrorMapping.verifyCodeOutcome(for: info, requestedAt: requestedAt ?? .distantPast)
    }

    // MARK: - Submit new password (AC13–AC16)

    func submitNewPassword(_ password: String) async -> NewPasswordOutcome {
        guard let application else { return .serviceUnavailable }
        guard let passwordRequiredState else {
            // The code step was never completed for this instance — the reset session is no
            // longer valid (e.g. the app was relaunched mid-journey).
            return .sessionExpired
        }
        guard connectivityMonitor.isOnline else {
            Self.logger.notice("Password submission blocked: device reports no connectivity")
            return .network
        }

        let delegate = ResetPasswordSubmitResultDelegate()
        let step = await delegate.run { passwordRequiredState.submitPassword(password: password, delegate: $0) }
        _ = application

        switch step {
        case .completed:
            Self.logger.debug("Password reset completed")
            cancel()
            return .completed
        case .failed(let error, let newState):
            self.passwordRequiredState = newState ?? self.passwordRequiredState
            return outcome(forSubmitError: error)
        }
    }

    private func outcome(forSubmitError error: PasswordRequiredError) -> NewPasswordOutcome {
        guard connectivityMonitor.isOnline else { return .network }
        let info = ResetErrorInfo(
            isInvalidPassword: error.isInvalidPassword,
            isBrowserRequired: error.isBrowserRequired,
            errorCodes: error.errorCodes
        )
        Self.logger.notice("Password submission failed with AADSTS codes: \(error.errorCodes, privacy: .public)")
        return PasswordResetErrorMapping.submitPasswordOutcome(for: info)
    }

    // MARK: - Cancel

    func cancel() {
        codeRequiredState = nil
        passwordRequiredState = nil
        requestedAt = nil
    }
}

// MARK: - Factory

extension MSALNativePasswordResetter {
    /// Builds the real resetter when `EntraConfiguration` resolves, or
    /// `NotConfiguredPasswordResetter` when it doesn't (ADR-0022 §6) — mirrors
    /// `MSALNativeAuthenticator.make(connectivityMonitor:)`.
    static func make(connectivityMonitor: ConnectivityMonitoring) -> any PasswordResetting {
        guard let configuration = try? EntraConfiguration() else {
            return NotConfiguredPasswordResetter()
        }
        return MSALNativePasswordResetter(configuration: configuration, connectivityMonitor: connectivityMonitor)
    }
}

/// Used whenever `EntraConfiguration` placeholders are not yet populated for this stage
/// (ADR-0022 §6). Every call reports `.notConfigured`/`.serviceUnavailable`/`.sessionExpired`; no
/// request is ever sent.
@MainActor
final class NotConfiguredPasswordResetter: PasswordResetting {
    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "auth")

    func requestCode(email _: String) async -> ResetCodeRequestOutcome {
        Self.logger.error(
            "Password reset attempted but Entra is not configured for this build — set CR_APP_CFG_ENTRA_CLIENT_ID / CR_APP_CFG_ENTRA_TENANT_SUBDOMAIN"
        )
        return .notConfigured
    }

    func verifyCode(_: String) async -> ResetCodeVerificationOutcome { .serviceUnavailable }
    func submitNewPassword(_: String) async -> NewPasswordOutcome { .sessionExpired }
    func cancel() {
        // No state to clear: sign-in is never configured for this stage (ADR-0022 §6).
    }
}

// MARK: - MSAL delegate → async bridges

private enum ResetPasswordStartStep {
    case codeRequired(ResetPasswordCodeRequiredState)
    case failed(ResetPasswordStartError)
}

/// Bridges MSAL's reset-password-start delegate callbacks to a single async result.
private final class ResetPasswordStartResultDelegate: NSObject, ResetPasswordStartDelegate {
    private var continuation: CheckedContinuation<ResetPasswordStartStep, Never>?

    func run(_ start: (ResetPasswordStartResultDelegate) -> Void) async -> ResetPasswordStartStep {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(self)
        }
    }

    private func finish(_ step: ResetPasswordStartStep) {
        continuation?.resume(returning: step)
        continuation = nil
    }

    func onResetPasswordStartError(error: ResetPasswordStartError) { finish(.failed(error)) }

    func onResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        finish(.codeRequired(newState))
    }
}

private enum ResetPasswordVerifyStep {
    case passwordRequired(ResetPasswordRequiredState)
    case failed(VerifyCodeError, ResetPasswordCodeRequiredState?)
}

/// Bridges MSAL's reset-password code-verification delegate callbacks to a single async result.
private final class ResetPasswordVerifyCodeResultDelegate: NSObject, ResetPasswordVerifyCodeDelegate {
    private var continuation: CheckedContinuation<ResetPasswordVerifyStep, Never>?

    func run(_ start: (ResetPasswordVerifyCodeResultDelegate) -> Void) async -> ResetPasswordVerifyStep {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(self)
        }
    }

    private func finish(_ step: ResetPasswordVerifyStep) {
        continuation?.resume(returning: step)
        continuation = nil
    }

    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?) {
        finish(.failed(error, newState))
    }

    func onPasswordRequired(newState: ResetPasswordRequiredState) {
        finish(.passwordRequired(newState))
    }
}

private enum ResetPasswordSubmitStep {
    case completed
    case failed(PasswordRequiredError, ResetPasswordRequiredState?)
}

/// Bridges MSAL's reset-password new-password-submission delegate callbacks to a single async
/// result. `SignInAfterResetPasswordState` (the completion payload) is intentionally discarded —
/// no automatic sign-in after reset (ADR-0027 §4).
private final class ResetPasswordSubmitResultDelegate: NSObject, ResetPasswordRequiredDelegate {
    private var continuation: CheckedContinuation<ResetPasswordSubmitStep, Never>?

    func run(_ start: (ResetPasswordSubmitResultDelegate) -> Void) async -> ResetPasswordSubmitStep {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(self)
        }
    }

    private func finish(_ step: ResetPasswordSubmitStep) {
        continuation?.resume(returning: step)
        continuation = nil
    }

    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?) {
        finish(.failed(error, newState))
    }

    func onResetPasswordCompleted(newState _: SignInAfterResetPasswordState) {
        finish(.completed)
    }
}
