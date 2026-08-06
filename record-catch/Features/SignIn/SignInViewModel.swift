//
//  SignInViewModel.swift
//  record-catch
//
//  UI-only view model for the Sign In screen. No networking, no auth, no
//  Keychain — the credential error is a stubbed presentational flag.
//

import Foundation

@MainActor
@Observable
final class SignInViewModel {

    var email: String = ""
    var password: String = ""

    /// Set once the user attempts to submit; drives when inline errors show.
    private(set) var didAttemptSubmit: Bool = false

    /// Stubbed generic credential error flag (UI only — no real auth).
    private(set) var showInvalidCredentials: Bool = false

    /// When `true`, a filled-but-"wrong" submit surfaces the stubbed credential
    /// error so the error state can be demonstrated/tested. Real auth is future work.
    private let stubInvalidCredentials: Bool

    init(stubInvalidCredentials: Bool = true) {
        self.stubInvalidCredentials = stubInvalidCredentials
    }

    /// Current email field error, once a submit has been attempted.
    var emailFieldError: SignInFieldError? {
        guard didAttemptSubmit else { return nil }
        return SignInValidation.emailError(email)
    }

    /// Current password field error, once a submit has been attempted.
    var passwordFieldError: SignInFieldError? {
        guard didAttemptSubmit else { return nil }
        return SignInValidation.passwordError(password)
    }

    /// Runs validation and updates presentational error state. No network.
    func submit() {
        didAttemptSubmit = true

        let formError = SignInValidation.formError(email: email, password: password)
        switch formError {
        case .missingFields:
            showInvalidCredentials = false
        case .none:
            // Fields present: in this UI-only phase, surface the stubbed
            // credential error to demonstrate the error summary state.
            showInvalidCredentials = stubInvalidCredentials
        case .invalidCredentials:
            showInvalidCredentials = true
        }
    }

    /// Clears the stubbed credential error, e.g. when the user edits a field.
    func clearCredentialError() {
        showInvalidCredentials = false
    }
}
