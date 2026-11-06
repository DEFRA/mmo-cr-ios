//
//  MSALNativeAuthenticator.swift
//  record-catch
//
//  Wraps MSAL Native Authentication (Microsoft Entra External ID) — ported from the
//  `entra-id-poc` sibling repository's `AuthenticationService.swift`, trimmed to sign-in, silent
//  session restore and sign-out only (no sign-up, no OTP, no protected-API scope — ADR-0022).
//
//  MSAL types are kept private to this file, mirroring the PoC's own isolation and the
//  `BiometricAuthenticating`/`KeychainStoring` seam pattern (ADR-0009): no other type in the app
//  ever imports `MSAL`.
//
//  Passwords and token values are never stored, exposed outside this file, or logged. Every
//  credential-revealing failure collapses to `.invalidCredentials` (ADR-0022 §3) — the detailed
//  AADSTS code is logged (public, non-PII) for diagnostics only.
//

import Foundation
import MSAL
import os

@MainActor
final class MSALNativeAuthenticator: Authenticating {

    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "auth")

    private let application: MSALNativeAuthPublicClientApplication?
    private let connectivityMonitor: ConnectivityMonitoring
    private var cachedUserAccount: MSALNativeAuthUserAccountResult?

    var hasCachedAccount: Bool {
        cachedUserAccount != nil || application?.getNativeAuthUserAccount() != nil
    }

    /// - Parameter configuration: Already validated (ADR-0022 §6) — this initialiser never fails
    ///   because of bad configuration shape. If MSAL itself fails to initialise (e.g. it rejects
    ///   the tenant subdomain for a reason `EntraConfiguration`'s shape check doesn't catch), every
    ///   method below returns `.serviceUnavailable` rather than crashing.
    init(configuration: EntraConfiguration, connectivityMonitor: ConnectivityMonitoring) {
        self.connectivityMonitor = connectivityMonitor

        // MSAL's own logging callback is never set, so no MSAL log output — including the
        // PII-masked-by-default messages — ever reaches the console or any log store (ADR-0022
        // §1). This is simpler and strictly quieter than configuring the callback.
        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: configuration.clientID,
                tenantSubdomain: configuration.tenantSubdomain,
                challengeTypes: [.password]
            )
            // Avoids requiring the `com.microsoft.adalcache` shared-keychain-access-group
            // entitlement: pointing MSAL's cache at this app's own bundle identifier uses a
            // private (non-shared) keychain group instead, per `MSALCacheConfig.keychainSharingGroup`'s
            // documented opt-out (ADR-0022 §6).
            if let bundleID = Bundle.main.bundleIdentifier {
                config.cacheConfig.keychainSharingGroup = bundleID
            }
            self.application = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
        } catch {
            Self.logger.error("Failed to initialise MSAL Native Auth application")
            self.application = nil
        }
    }

    // MARK: - Sign in

    func signIn(email: String, password: String) async -> SignInOutcome {
        guard let application else { return .serviceUnavailable }
        guard connectivityMonitor.isOnline else { return .network }

        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password

        let delegate = SignInResultDelegate()
        var step = await delegate.run { application.signIn(parameters: parameters, delegate: $0) }

        // Mirrors the PoC: if MSAL still asks for the password, submit the one already entered
        // once more before giving up.
        if case .passwordRequired(let state) = step {
            step = await delegate.run { state.submitPassword(password: password, delegate: $0) }
        }

        return handle(step)
    }

    private func handle(_ step: SignInStep) -> SignInOutcome {
        switch step {
        case .completed(let result):
            cachedUserAccount = result
            return .success(Self.makeAccount(result.account))
        case .codeRequired, .passwordRequired, .unsupported:
            // Email-OTP / repeated password prompts / MFA are not supported by this screen
            // (ADR-0022 §1/§8) — treated as a service-level failure, never as a credential leak.
            return .serviceUnavailable
        case .failed(let error):
            return map(error)
        }
    }

    // MARK: - Silent session restore

    func restoreSession() async -> RestoreSessionOutcome {
        guard let application else { return .reauthenticationRequired }
        guard let userAccount = cachedUserAccount ?? application.getNativeAuthUserAccount() else {
            return .noAccount
        }
        cachedUserAccount = userAccount

        guard connectivityMonitor.isOnline else { return .network }

        let parameters = MSALNativeAuthGetAccessTokenParameters()
        let delegate = TokenResultDelegate()
        let result = await delegate.run { userAccount.getAccessToken(parameters: parameters, delegate: $0) }

        switch result {
        case .success:
            return .success(Self.makeAccount(userAccount.account))
        case .failure:
            return .reauthenticationRequired
        }
    }

    // MARK: - Sign out

    func signOut() async {
        cachedUserAccount?.signOut()
        application?.getNativeAuthUserAccount()?.signOut()
        cachedUserAccount = nil
    }

    // MARK: - Helpers

    private static func makeAccount(_ account: MSALAccount) -> AuthenticatedAccount {
        AuthenticatedAccount(
            username: account.username ?? "Unknown user",
            identifier: account.identifier ?? "Unknown identifier"
        )
    }

    /// Maps every MSAL/Entra failure to an app-level outcome. Every credential-revealing case —
    /// user not found, invalid username, wrong password — collapses to `.invalidCredentials`, so
    /// the UI can never be used to enumerate which email addresses have accounts (ADR-0022 §3,
    /// security-critical path — 100% test coverage target).
    private func map(_ error: Error) -> SignInOutcome {
        guard connectivityMonitor.isOnline else { return .network }

        guard let nativeError = error as? MSALNativeAuthError else {
            Self.logger.error("Sign-in failed with a non-MSAL error")
            return .serviceUnavailable
        }

        if nativeError.isBrowserRequired {
            return .serviceUnavailable
        }
        if let startError = nativeError as? SignInStartError,
           startError.isUserNotFound || startError.isInvalidUsername || startError.isInvalidCredentials {
            Self.logSuppressedCredentialFailure(nativeError)
            return .invalidCredentials
        }
        if let passwordError = nativeError as? PasswordRequiredError, passwordError.isInvalidPassword {
            Self.logSuppressedCredentialFailure(nativeError)
            return .invalidCredentials
        }

        Self.logger.error("Sign-in failed with AADSTS codes: \(nativeError.errorCodes, privacy: .public)")
        return .serviceUnavailable
    }

    private static func logSuppressedCredentialFailure(_ error: MSALNativeAuthError) {
        // The AADSTS code is logged (public, non-PII) for diagnostics; the detailed reason is
        // never surfaced to the UI — only the generic `.invalidCredentials` outcome is.
        logger.notice("Sign-in credential failure suppressed to generic outcome; AADSTS codes: \(error.errorCodes, privacy: .public)")
    }
}

// MARK: - Factory

extension MSALNativeAuthenticator {
    /// Builds the real authenticator when `EntraConfiguration` resolves, or
    /// `NotConfiguredAuthenticator` when it doesn't (ADR-0022 §6) — so `RootSessionCoordinator`
    /// never has to deal with `EntraConfiguration`'s throwing initialiser directly.
    static func make(connectivityMonitor: ConnectivityMonitoring) -> any Authenticating {
        guard let configuration = try? EntraConfiguration() else {
            return NotConfiguredAuthenticator()
        }
        return MSALNativeAuthenticator(configuration: configuration, connectivityMonitor: connectivityMonitor)
    }
}

/// Used whenever `EntraConfiguration` placeholders are not yet populated for this stage
/// (ADR-0022 §6). Every sign-in attempt reports `.notConfigured`; there is no cached account and
/// no fallback to another backend/tenant.
@MainActor
final class NotConfiguredAuthenticator: Authenticating {
    let hasCachedAccount = false

    func signIn(email _: String, password _: String) async -> SignInOutcome { .notConfigured }
    func restoreSession() async -> RestoreSessionOutcome { .noAccount }
    func signOut() async {
        // No-op: sign-in is never configured for this stage (ADR-0022 §6), so there is never a
        // session to sign out of.
    }
}

// MARK: - MSAL delegate → async bridges

/// Outcome of one step of the native sign-in flow.
private enum SignInStep {
    case completed(MSALNativeAuthUserAccountResult)
    case codeRequired
    case passwordRequired(SignInPasswordRequiredState)
    case unsupported
    case failed(Error)
}

/// Bridges MSAL's sign-in delegate callbacks to a single async result per step.
private final class SignInResultDelegate: NSObject, SignInStartDelegate, SignInPasswordRequiredDelegate {
    private var continuation: CheckedContinuation<SignInStep, Never>?

    func run(_ start: (SignInResultDelegate) -> Void) async -> SignInStep {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(self)
        }
    }

    private func finish(_ step: SignInStep) {
        continuation?.resume(returning: step)
        continuation = nil
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) { finish(.completed(result)) }

    func onSignInCodeRequired(
        newState _: SignInCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        finish(.codeRequired)
    }

    func onSignInPasswordRequired(newState: SignInPasswordRequiredState) {
        finish(.passwordRequired(newState))
    }

    func onSignInAwaitingMFA(authMethods _: [MSALAuthMethod], newState _: AwaitingMFAState) {
        finish(.unsupported)
    }

    func onSignInStrongAuthMethodRegistration(authMethods _: [MSALAuthMethod], newState _: RegisterStrongAuthState) {
        finish(.unsupported)
    }

    func onSignInStartError(error: SignInStartError) { finish(.failed(error)) }

    func onSignInPasswordRequiredError(error: PasswordRequiredError, newState _: SignInPasswordRequiredState?) {
        finish(.failed(error))
    }
}

/// Bridges MSAL's silent-token-acquisition delegate to a single async result.
private final class TokenResultDelegate: NSObject, CredentialsDelegate {
    private var continuation: CheckedContinuation<Result<MSALNativeAuthTokenResult, Error>, Never>?

    func run(_ start: (TokenResultDelegate) -> Void) async -> Result<MSALNativeAuthTokenResult, Error> {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(self)
        }
    }

    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult) {
        continuation?.resume(returning: .success(result))
        continuation = nil
    }

    func onAccessTokenRetrieveError(error: RetrieveAccessTokenError) {
        continuation?.resume(returning: .failure(error))
        continuation = nil
    }
}
