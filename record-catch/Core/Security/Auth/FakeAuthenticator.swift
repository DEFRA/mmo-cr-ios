//
//  FakeAuthenticator.swift
//  record-catch
//
//  Deterministic test/preview/UI-test double for `Authenticating` (ADR-0022 §2/§10). Never
//  touches MSAL, the network, or the Keychain.
//

import Foundation

@MainActor
final class FakeAuthenticator: Authenticating {
    /// Outcome returned by the next `signIn(email:password:)` call, chosen by the caller (unit
    /// tests) or derived from the entered email (UI-test stub — see `make(forEmail:)`).
    var signInOutcome: SignInOutcome
    /// Outcome returned by `restoreSession()`.
    var restoreSessionOutcome: RestoreSessionOutcome
    /// A fixed token returned by `accessToken()` whenever `hasCachedAccount` is `true`; `nil`
    /// simulates the Catch Recording Service's scope not being configured for this stage, or any
    /// other silent-token-acquisition failure (see `Authenticating.accessToken()`).
    var accessTokenResult: String?
    /// An artificial delay before `signIn` resolves, so callers can exercise the EC1
    /// loading/anti-double-submit state deterministically.
    var signInDelayNanoseconds: UInt64
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var accessTokenCallCount = 0

    var hasCachedAccount: Bool

    init(
        signInOutcome: SignInOutcome = .success(AuthenticatedAccount(username: "test@example.com", identifier: "fake-id")),
        restoreSessionOutcome: RestoreSessionOutcome = .noAccount,
        hasCachedAccount: Bool = false,
        accessTokenResult: String? = nil,
        signInDelayNanoseconds: UInt64 = 0
    ) {
        self.signInOutcome = signInOutcome
        self.restoreSessionOutcome = restoreSessionOutcome
        self.hasCachedAccount = hasCachedAccount
        self.accessTokenResult = accessTokenResult
        self.signInDelayNanoseconds = signInDelayNanoseconds
    }

    func signIn(email _: String, password _: String) async -> SignInOutcome {
        signInCallCount += 1
        if signInDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: signInDelayNanoseconds)
        }
        if case .success(let account) = signInOutcome {
            hasCachedAccount = true
            return .success(account)
        }
        return signInOutcome
    }

    func restoreSession() async -> RestoreSessionOutcome {
        restoreSessionOutcome
    }

    func signOut() async {
        signOutCallCount += 1
        hasCachedAccount = false
    }

    func accessToken() async -> String? {
        accessTokenCallCount += 1
        guard hasCachedAccount else { return nil }
        return accessTokenResult
    }
}

extension FakeAuthenticator {
    /// Builds a `FakeAuthenticator` whose `signIn` outcome is derived from the email the user
    /// entered — the `-uiTestAuthStub` seam (ADR-0022 §10) used by `SignInUITests` so XCUITest
    /// never depends on network access to a real Entra tenant.
    ///
    /// Reserved `example.com` test addresses only:
    /// - `invalid@example.com` → `.invalidCredentials`
    /// - `offline@example.com` → `.network`
    /// - `slow@example.com` → succeeds after a short delay (exercises EC1's loading state)
    /// - anything else → succeeds immediately
    static func makeUITestStub() -> UITestStubAuthenticator {
        UITestStubAuthenticator()
    }
}

/// Backs the `-uiTestAuthStub` seam: chooses its `signIn` outcome from the email entered, rather
/// than a single fixed outcome (unlike the general-purpose `FakeAuthenticator` used by unit
/// tests/previews).
@MainActor
final class UITestStubAuthenticator: Authenticating {
    private enum StubEmail {
        static let invalidCredentials = "invalid@example.com"
        static let offline = "offline@example.com"
        static let slow = "slow@example.com"
    }

    private static let slowDelayNanoseconds: UInt64 = 2_000_000_000

    private(set) var hasCachedAccount = false

    func signIn(email: String, password _: String) async -> SignInOutcome {
        let normalised = SignInValidation.normalisedEmail(email)
        switch normalised {
        case StubEmail.invalidCredentials:
            return .invalidCredentials
        case StubEmail.offline:
            return .network
        case StubEmail.slow:
            try? await Task.sleep(nanoseconds: Self.slowDelayNanoseconds)
            hasCachedAccount = true
            return .success(AuthenticatedAccount(username: normalised, identifier: "uitest-stub"))
        default:
            hasCachedAccount = true
            return .success(AuthenticatedAccount(username: normalised, identifier: "uitest-stub"))
        }
    }

    func restoreSession() async -> RestoreSessionOutcome {
        .noAccount
    }

    func signOut() async {
        hasCachedAccount = false
    }

    /// UI tests never exercise real network calls, so there is no "Catch Recording Service scope"
    /// to simulate here — always `nil` (mirrors the stub's "no live network" scope, see this
    /// type's own doc comment).
    func accessToken() async -> String? { nil }
}
