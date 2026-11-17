//
//  ResetPasswordViewModel.swift
//  record-catch
//
//  View model for the "Reset your password" screen (AC1–AC3, AC9, ADR-0027).
//

import Foundation

/// Form-level error for the "Reset your password" screen.
enum ResetPasswordFormError: Equatable {
    case missingOrInvalidEmail
    case network
    case serviceUnavailable
    case notConfigured

    var localizationKey: String? {
        switch self {
        case .missingOrInvalidEmail: return nil
        case .network, .serviceUnavailable, .notConfigured: return "passwordReset.error.service"
        }
    }
}

@MainActor
@Observable
final class ResetPasswordViewModel {

    var email: String = ""
    private(set) var didAttemptSubmit = false
    private(set) var isSubmitting = false
    private(set) var formError: ResetPasswordFormError?

    private let resetter: any PasswordResetting
    private let router: PasswordResetRouter

    init(resetter: any PasswordResetting, router: PasswordResetRouter) {
        self.resetter = resetter
        self.router = router
    }

    var emailFieldError: ResetEmailFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingOrInvalidEmail else { return nil }
        return PasswordResetValidation.emailError(email)
    }

    var showFormErrorSummary: Bool {
        guard let formError else { return false }
        return formError != .missingOrInvalidEmail
    }

    /// Validates, then — only if valid — requests a reset code (AC2/AC3). Guards against a second
    /// concurrent request from rapid repeated taps, mirroring `SignInViewModel.submit()`.
    func submit() async {
        guard !isSubmitting else { return }
        didAttemptSubmit = true

        let fieldError = PasswordResetValidation.emailError(email)
        formError = fieldError == nil ? nil : .missingOrInvalidEmail
        guard fieldError == nil else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let normalisedEmail = PasswordResetValidation.normalisedEmail(email)
        switch await resetter.requestCode(email: normalisedEmail) {
        case .codeSent:
            formError = nil
            router.push(.enterCode)
        case .network:
            formError = .network
        case .serviceUnavailable:
            formError = .serviceUnavailable
        case .notConfigured:
            formError = .notConfigured
        }
    }

    func clearFormError() {
        formError = nil
    }
}
