//
//  Authenticating.swift
//  record-catch
//
//  Authentication seam (ADR-0022 §2): the view model and `RootSessionCoordinator` depend only on
//  this protocol. `MSALNativeAuthenticator` is the sole real (MSAL-backed) implementation;
//  `FakeAuthenticator` is an in-memory double for previews/tests/UI-test stubbing. No other type
//  in the app ever imports `MSAL` directly, mirroring the `BiometricAuthenticating`/
//  `KeychainStoring` seam pattern from ADR-0009.
//

import Foundation

/// A signed-in Entra account. Carries only a display username and MSAL's opaque account
/// identifier — never a token (ADR-0022 §4).
nonisolated struct AuthenticatedAccount: Equatable, Sendable {
    let username: String
    let identifier: String
}

/// Result of a `signIn(email:password:)` attempt. Every credential-revealing MSAL failure
/// (unknown user, wrong password, invalid username) collapses to `.invalidCredentials`
/// (ADR-0022 §3 — a security-critical, 100%-covered mapping).
enum SignInOutcome: Equatable {
    case success(AuthenticatedAccount)
    case invalidCredentials
    /// No network connectivity — sign-in was not attempted.
    case network
    /// Any other Entra/MSAL failure, including an unsupported step (MFA, browser-required,
    /// email-code-required) and rate-limiting/lockout. One provisional outcome pending product
    /// content (ADR-0022 §7).
    case serviceUnavailable
    /// `EntraConfiguration` placeholders are not yet populated for this stage.
    case notConfigured
}

/// Result of a silent session restore (`restoreSession()`), used at launch and on return to the
/// foreground (ADR-0022 §5).
enum RestoreSessionOutcome: Equatable {
    case success(AuthenticatedAccount)
    /// No cached MSAL account exists on this device.
    case noAccount
    /// No network connectivity — the caller should fall back to the offline policy.
    case network
    /// The refresh token is expired/revoked, or some other non-network failure occurred — the
    /// caller must treat the local session as no longer valid.
    case reauthenticationRequired
}

@MainActor
protocol Authenticating: AnyObject {
    /// Whether MSAL has a cached account on this device, without attempting any network call.
    var hasCachedAccount: Bool { get }

    /// Signs in with an email + password. `email` is used as-is (callers normalise/validate
    /// before calling — see `SignInValidation`).
    func signIn(email: String, password: String) async -> SignInOutcome

    /// Attempts a silent token refresh for the cached account, if any (ADR-0022 §5).
    func restoreSession() async -> RestoreSessionOutcome

    /// Signs out, clearing MSAL's local token cache.
    func signOut() async

    /// Resolves a bearer access token, scoped to the Catch Recording Service's API permission
    /// (ADR-0022 addendum, ADR-0025), for the cached account — or `nil` when there is no cached
    /// account, the service's scope is not configured for this stage, or the silent token request
    /// fails for any reason. Never throws: a missing token is a normal, expected outcome (the
    /// service is not yet registered for every stage — see `EntraConfiguration`/ADR-0025), not an
    /// error condition a caller must handle specially. The token itself is never cached, stored, or
    /// logged by this app — MSAL's own Keychain cache is the only place it lives (ADR-0022 §4).
    func accessToken() async -> String?
}
