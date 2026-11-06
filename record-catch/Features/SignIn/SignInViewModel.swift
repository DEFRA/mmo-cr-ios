//
//  SignInViewModel.swift
//  record-catch
//
//  Sign In screen view model (ADR-0022): real authentication via `Authenticating`, replacing the
//  earlier UI-only stub. Validation stays in the pure `SignInValidation` helper; this type
//  orchestrates calling the authenticator and mapping its outcome to presentational state.
//

import Foundation

@MainActor
@Observable
final class SignInViewModel {

    var email: String = ""
    var password: String = ""

    /// Set once the user attempts to submit; drives when inline errors show.
    private(set) var didAttemptSubmit: Bool = false

    /// `true` while a sign-in request is in flight. Drives the button's loading state and guards
    /// against a second concurrent request from rapid repeated taps (EC1).
    private(set) var isSubmitting: Bool = false

    /// The current form-level error, if any (credential failure, network, service, or
    /// not-configured). `nil` once cleared or never set.
    private(set) var formError: SignInFormError?

    private let authenticator: any Authenticating
    /// Called once, after a successful sign-in.
    private let onSignedIn: (AuthenticatedAccount) -> Void

    /// - Parameter authenticator: No default — Swift default-argument expressions are not
    ///   actor-isolated, so a `@MainActor`-isolated fake (e.g. `FakeAuthenticator()`) cannot be
    ///   constructed as one. Callers (`SignInView.init`, tests) always supply one explicitly.
    init(
        authenticator: any Authenticating,
        onSignedIn: @escaping (AuthenticatedAccount) -> Void = { _ in
            // No-op default: previews/tests that don't care about the destination.
        }
    ) {
        self.authenticator = authenticator
        self.onSignedIn = onSignedIn
    }

    /// Current email field error, once a submit has been attempted. Suppressed once a
    /// backend-driven `formError` (credentials/network/service/not-configured) is set — at that
    /// point the password has already been cleared for this attempt (see `submit()`), so
    /// recomputing from the live field would wrongly report "password empty".
    var emailFieldError: SignInFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingOrInvalidFields else { return nil }
        return SignInValidation.emailError(email)
    }

    /// Current password field error — see `emailFieldError`'s doc comment for the suppression
    /// rule shared with this property.
    var passwordFieldError: SignInFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingOrInvalidFields else { return nil }
        return SignInValidation.passwordError(password)
    }

    /// Whether a form-level (credential/network/service) error summary should show.
    var showFormErrorSummary: Bool {
        guard let formError else { return false }
        return formError != .missingOrInvalidFields
    }

    /// Validates, then — only if the form is valid — calls the authenticator. Ignored while a
    /// request is already in flight, so repeated taps submit at most one request (EC1, ES1–ES4).
    func submit() async {
        guard !isSubmitting else { return }
        didAttemptSubmit = true

        let normalisedEmail = SignInValidation.normalisedEmail(email)
        let outcome = SignInValidation.formError(email: email, password: password)
        formError = outcome
        guard outcome == .none else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let result = await authenticator.signIn(email: normalisedEmail, password: password)
        // The password is cleared after every attempt, success or failure (security.instructions.md:
        // never retain a credential longer than needed to submit it).
        password = ""

        switch result {
        case .success(let account):
            formError = nil
            onSignedIn(account)
        case .invalidCredentials:
            formError = .invalidCredentials
        case .network:
            formError = .network
        case .serviceUnavailable:
            formError = .serviceUnavailable
        case .notConfigured:
            formError = .notConfigured
        }
    }

    /// Clears any form-level error, e.g. when the user edits a field.
    func clearFormError() {
        formError = nil
    }
}
