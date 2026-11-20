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
    /// The Catch Recording Service's API scope (ADR-0022 addendum, ADR-0025), when configured for
    /// this stage. `nil` until the Entra tenant team registers the service.
    private let catchRecordAPIScope: String?
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
        self.catchRecordAPIScope = configuration.catchRecordAPIScope

        // MSAL's own logging callback is never set, so no MSAL log output — including the
        // PII-masked-by-default messages — ever reaches the console or any log store (ADR-0022
        // §1). This is simpler and strictly quieter than configuring the callback.
        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: configuration.clientID,
                tenantSubdomain: configuration.tenantSubdomain,
                // `.OOB` added alongside `.password` for self-service password reset's emailed
                // code step (ADR-0027 §1, supersedes ADR-0022 §1). Sign-in's own negotiation is
                // unaffected: an unexpected `codeRequired` step already maps to
                // `.serviceUnavailable` below.
                challengeTypes: [.OOB, .password]
            )
            // Deliberately NOT overriding `cacheConfig.keychainSharingGroup` here (a private,
            // bundle-ID-scoped group was tried and reverted — see git history / incident notes).
            // MSAL Native Auth's own silent-token path (`getAccessTokenInternal`, used by both
            // `restoreSession()` and `accessToken()` below) rebuilds a brand-new
            // `MSALNativeAuthPublicClientApplicationConfig` internally for every silent call and
            // never copies this app's `cacheConfig` across — its keychain group always falls back
            // to the SDK's static default (`com.microsoft.adalcache`), regardless of what's set
            // here. Overriding the group only on `self.application` therefore made sign-in write
            // the refresh token under one keychain access group while every later silent token
            // request looked for it under a *different* one — guaranteed to never find it
            // (confirmed by reading `MSALPublicClientApplication.m` and
            // `MSIDSilentTokenRequest.m` in the local MSAL 2.17.0 checkout). Leaving this unset
            // lets every code path — this instance and MSAL's internally-reconstructed ones —
            // consistently use the SDK's real default group instead, which this app is entitled
            // for via `keychain-access-groups` (`$(AppIdentifierPrefix)com.microsoft.adalcache`,
            // per MSAL's own "Configure keychain" guidance).
            self.application = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
            // Tenant subdomain is public (non-secret) app-registration metadata — never the
            // client ID or any token — so it is safe to confirm at debug level.
            Self.logger.debug(
                "MSAL Native Auth application initialised (tenant subdomain: \(configuration.tenantSubdomain, privacy: .public))"
            )
        } catch {
            Self.logger.error("Failed to initialise MSAL Native Auth application")
            self.application = nil
        }
    }

    // MARK: - Sign in

    func signIn(email: String, password: String) async -> SignInOutcome {
        Self.logger.debug("Sign-in requested")

        guard let application else {
            Self.logger.error("Sign-in blocked: MSAL application failed to initialise — check ENTRA_CLIENT_ID/ENTRA_TENANT_SUBDOMAIN")
            return .serviceUnavailable
        }
        guard connectivityMonitor.isOnline else {
            Self.logger.notice("Sign-in blocked: device reports no connectivity")
            return .network
        }

        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password
        // Request the Catch Recording Service's API scope (ADR-0022 addendum, ADR-0025) up front,
        // alongside the implicit openid/profile/offline_access scopes. Without this, the
        // sign-in-issued token/refresh-token grant never covers `catchRecordAPIScope`, so the
        // later silent `getAccessToken(parameters:)` call in `accessToken()` below has nothing to
        // return and fails with MSAL's "No token matching arguments found in the cache, user
        // interaction is required" — confirmed via `lldb`/runtime diagnostics, not a keychain
        // issue. Requires the scope to already be an admin-consented API permission on this app's
        // Entra registration (ADR-0025) — if that consent is missing, sign-in itself will instead
        // report an error for the missing/unconsented scope rather than silently dropping it.
        if let catchRecordAPIScope {
            parameters.scopes = [catchRecordAPIScope]
        }

        let delegate = SignInResultDelegate()
        var step = await delegate.run { application.signIn(parameters: parameters, delegate: $0) }

        // Mirrors the PoC: if MSAL still asks for the password, submit the one already entered
        // once more before giving up.
        if case .passwordRequired(let state) = step {
            Self.logger.debug("MSAL requested the password again; resubmitting once")
            step = await delegate.run { state.submitPassword(password: password, delegate: $0) }
        }

        let outcome = handle(step)
        if case .success = outcome {
            // Eagerly fetch the Catch Recording Service access token right after sign-in, so
            // there's something to inspect in the debugger during local dev (ADR-0022 addendum,
            // ADR-0025) — no view calls `accessToken()` yet, so without this it would never run.
            // The return value is discarded here deliberately: see `accessToken()` below for why
            // its value is never logged/printed; use a breakpoint there instead.
            _ = await accessToken()
        }
        Self.logger.debug("Sign-in finished with outcome: \(Self.describe(outcome), privacy: .public)")
        return outcome
    }

    private func handle(_ step: SignInStep) -> SignInOutcome {
        switch step {
        case .completed(let result):
            cachedUserAccount = result
            return .success(Self.makeAccount(result.account))
        case .codeRequired, .passwordRequired, .unsupported:
            // Email-OTP / repeated password prompts / MFA are not supported by this screen
            // (ADR-0022 §1/§8) — treated as a service-level failure, never as a credential leak.
            Self.logger.notice("Sign-in step unsupported by this screen (OTP/repeated-password/MFA) — reporting serviceUnavailable")
            return .serviceUnavailable
        case .failed(let error):
            return map(error)
        }
    }

    /// Logs only the outcome *kind* — never the wrapped `AuthenticatedAccount` (which carries a
    /// username/identifier) — so this stays safe to log at debug level.
    private static func describe(_ outcome: SignInOutcome) -> String {
        switch outcome {
        case .success: return "success"
        case .invalidCredentials: return "invalidCredentials"
        case .network: return "network"
        case .serviceUnavailable: return "serviceUnavailable"
        case .notConfigured: return "notConfigured"
        }
    }

    // MARK: - Silent session restore

    func restoreSession() async -> RestoreSessionOutcome {
        guard let application else {
            Self.logger.notice("Restore session skipped: MSAL application not initialised")
            return .reauthenticationRequired
        }
        guard let userAccount = cachedUserAccount ?? application.getNativeAuthUserAccount() else {
            Self.logger.debug("Restore session: no cached account on this device")
            return .noAccount
        }
        cachedUserAccount = userAccount

        guard connectivityMonitor.isOnline else {
            Self.logger.notice("Restore session blocked: device reports no connectivity")
            return .network
        }

        let parameters = MSALNativeAuthGetAccessTokenParameters()
        let delegate = TokenResultDelegate()
        let result = await delegate.run { userAccount.getAccessToken(parameters: parameters, delegate: $0) }

        switch result {
        case .success:
            Self.logger.debug("Restore session succeeded (silent token refresh)")
            return .success(Self.makeAccount(userAccount.account))
        case .failure:
            Self.logger.notice("Restore session failed: refresh token expired/revoked — reauthentication required")
            return .reauthenticationRequired
        }
    }

    // MARK: - Sign out

    func signOut() async {
        cachedUserAccount?.signOut()
        application?.getNativeAuthUserAccount()?.signOut()
        cachedUserAccount = nil
    }

    // MARK: - Catch Recording Service access token (ADR-0022 addendum, ADR-0025)

    /// Resolves a bearer token scoped to `catchRecordAPIScope`, for use by
    /// `MSALAccessTokenProvider` (`Core/Networking/MSALAccessTokenProvider.swift`). See the
    /// `Authenticating.accessToken()` doc comment for the full contract — in particular, this never
    /// throws and degrades to `nil` for every failure mode.
    func accessToken() async -> String? {
        guard let application, let catchRecordAPIScope else { return nil }
        guard let userAccount = cachedUserAccount ?? application.getNativeAuthUserAccount() else { return nil }
        cachedUserAccount = userAccount
        guard connectivityMonitor.isOnline else { return nil }

        let parameters = MSALNativeAuthGetAccessTokenParameters()
        parameters.scopes = [catchRecordAPIScope]
        let delegate = TokenResultDelegate()
        let result = await delegate.run { userAccount.getAccessToken(parameters: parameters, delegate: $0) }

        switch result {
        case .success(let tokenResult):
            // Never logs/prints the token value itself (a bearer credential — security
            // instructions forbid logging secrets/tokens in plaintext, and `print`/log output can
            // end up in a device sysdiagnose or a user-shared diagnostics export, ADR-0022 §1).
            // The scope string is non-secret (an API permission identifier, not a credential) and
            // the length is non-reversible, so both are safe to confirm at debug level that a
            // token really was obtained. For local dev inspection of the actual value, use the
            // debugger (breakpoint here + `po tokenResult.accessToken`) — that's ephemeral and
            // never persisted, unlike `print`/`Logger`.
            Self.logger.debug(
                "Access token obtained for Catch Recording Service (scope: \(catchRecordAPIScope, privacy: .public), length: \(tokenResult.accessToken.count, privacy: .public))"
            )
            return tokenResult.accessToken
        case .failure(let error):
            // Logs the AADSTS error code(s) (public, non-PII — same pattern as `map(_:)` for
            // sign-in failures) so a genuinely missing protected-API token is diagnosable without
            // ever logging a credential. Common causes once sign-in itself succeeds: the scope
            // isn't added as an API permission on the client app registration, admin consent
            // hasn't been granted for it, or the resource app's Application ID URI/scope name
            // doesn't match `catchRecordAPIScope` exactly (ADR-0025).
            if let nativeError = error as? MSALNativeAuthError {
                Self.logger.notice(
                    "Access token request failed for Catch Recording Service scope (\(catchRecordAPIScope, privacy: .public)); AADSTS codes: \(nativeError.errorCodes, privacy: .public)"
                )
            } else {
                Self.logger.notice(
                    "Access token request failed for Catch Recording Service scope (\(catchRecordAPIScope, privacy: .public)), with a non-MSAL error"
                )
            }
            return nil
        }
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
    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "auth")

    let hasCachedAccount = false

    func signIn(email _: String, password _: String) async -> SignInOutcome {
        // The most common reason a developer "can't sign in" locally: ENTRA_CLIENT_ID /
        // ENTRA_TENANT_SUBDOMAIN are unset or malformed for this stage, which is expected and
        // optional per Config/Local.xcconfig.example (ADR-0022 §6) — but worth surfacing loudly.
        Self.logger.error(
            "Sign-in attempted but Entra is not configured for this build — set CR_APP_CFG_ENTRA_CLIENT_ID / CR_APP_CFG_ENTRA_TENANT_SUBDOMAIN (see Config/Local.xcconfig.example)"
        )
        return .notConfigured
    }

    func restoreSession() async -> RestoreSessionOutcome {
        Self.logger.debug("Restore session skipped: Entra is not configured for this build")
        return .noAccount
    }

    func signOut() async {
        // No-op: sign-in is never configured for this stage (ADR-0022 §6), so there is never a
        // session to sign out of.
    }
    func accessToken() async -> String? { nil }
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
