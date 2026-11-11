//
//  FakePasswordResetter.swift
//  record-catch
//
//  Deterministic test/preview/UI-test double for `PasswordResetting` (ADR-0027 §2). Never touches
//  MSAL, the network, or the Keychain. Mirrors `FakeAuthenticator`/`UITestStubAuthenticator`.
//

import Foundation

@MainActor
final class FakePasswordResetter: PasswordResetting {
    var requestCodeOutcome: ResetCodeRequestOutcome
    var verifyCodeOutcome: ResetCodeVerificationOutcome
    var submitNewPasswordOutcome: NewPasswordOutcome
    /// An artificial delay before `requestCode` resolves, so callers can exercise an
    /// anti-double-submit guard deterministically (mirrors `FakeAuthenticator.signInDelayNanoseconds`).
    var requestCodeDelayNanoseconds: UInt64 = 0
    private(set) var requestCodeCallCount = 0
    private(set) var verifyCodeCallCount = 0
    private(set) var submitNewPasswordCallCount = 0
    private(set) var cancelCallCount = 0
    private(set) var lastRequestedEmail: String?
    private(set) var lastVerifiedCode: String?
    private(set) var lastSubmittedPassword: String?

    init(
        requestCodeOutcome: ResetCodeRequestOutcome = .codeSent,
        verifyCodeOutcome: ResetCodeVerificationOutcome = .verified,
        submitNewPasswordOutcome: NewPasswordOutcome = .completed
    ) {
        self.requestCodeOutcome = requestCodeOutcome
        self.verifyCodeOutcome = verifyCodeOutcome
        self.submitNewPasswordOutcome = submitNewPasswordOutcome
    }

    func requestCode(email: String) async -> ResetCodeRequestOutcome {
        requestCodeCallCount += 1
        lastRequestedEmail = email
        if requestCodeDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: requestCodeDelayNanoseconds)
        }
        return requestCodeOutcome
    }

    func verifyCode(_ code: String) async -> ResetCodeVerificationOutcome {
        verifyCodeCallCount += 1
        lastVerifiedCode = code
        return verifyCodeOutcome
    }

    func submitNewPassword(_ password: String) async -> NewPasswordOutcome {
        submitNewPasswordCallCount += 1
        lastSubmittedPassword = password
        return submitNewPasswordOutcome
    }

    func cancel() {
        cancelCallCount += 1
    }
}

/// Backs the `-uiTestAuthStub` seam for the password-reset journey (ADR-0027 §2/ADR-0022 §10):
/// chooses its outcome from the email/code/password entered, rather than one fixed outcome.
///
/// Reserved `example.com` test values only:
/// - `offline@example.com` → `.network` on `requestCode`
/// - `error@example.com` → `.serviceUnavailable` on `requestCode`
/// - code `11111111` → `.invalidCode`
/// - code `22222222` → `.expired`
/// - any other non-blank code → `.verified`
/// - password `TestWeakPassword1!` → `.doesNotMeetPolicy`
/// - any other password → `.completed`
@MainActor
final class UITestStubPasswordResetter: PasswordResetting {
    private enum Stub {
        static let offlineEmail = "offline@example.com"
        static let errorEmail = "error@example.com"
        static let invalidCode = "11111111"
        static let expiredCode = "22222222"
        static let weakPassword = "TestWeakPassword1!"
    }

    func requestCode(email: String) async -> ResetCodeRequestOutcome {
        switch PasswordResetValidation.normalisedEmail(email) {
        case Stub.offlineEmail: return .network
        case Stub.errorEmail: return .serviceUnavailable
        default: return .codeSent
        }
    }

    func verifyCode(_ code: String) async -> ResetCodeVerificationOutcome {
        switch PasswordResetValidation.normalisedCode(code) {
        case Stub.invalidCode: return .invalidCode
        case Stub.expiredCode: return .expired
        default: return .verified
        }
    }

    func submitNewPassword(_ password: String) async -> NewPasswordOutcome {
        password == Stub.weakPassword ? .doesNotMeetPolicy : .completed
    }

    func cancel() {
        // No state to clear in the stub.
    }
}
