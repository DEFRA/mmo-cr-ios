//
//  CreateNewPasswordViewModel.swift
//  record-catch
//
//  View model for the "Create a new password" screen (AC11–AC16, ADR-0027).
//

import Foundation

enum NewPasswordFormError: Equatable {
    case missingOrInvalidFields
    case doesNotMeetPolicy
    case sessionExpired
    case network
    case serviceUnavailable

    var localizationKey: String? {
        switch self {
        case .missingOrInvalidFields: return nil
        case .doesNotMeetPolicy: return "passwordReset.newPassword.error.requirements"
        case .sessionExpired: return "passwordReset.error.sessionExpired"
        case .network, .serviceUnavailable: return "passwordReset.error.service"
        }
    }
}

@MainActor
@Observable
final class CreateNewPasswordViewModel {

    var newPassword: String = ""
    var confirmPassword: String = ""
    private(set) var didAttemptSubmit = false
    private(set) var isSubmitting = false
    private(set) var formError: NewPasswordFormError?

    private let resetter: any PasswordResetting
    private let router: PasswordResetRouter

    init(resetter: any PasswordResetting, router: PasswordResetRouter) {
        self.resetter = resetter
        self.router = router
    }

    var newPasswordFieldError: NewPasswordFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingOrInvalidFields else { return nil }
        return PasswordResetValidation.newPasswordError(newPassword)
    }

    var confirmPasswordFieldError: ConfirmPasswordFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingOrInvalidFields else { return nil }
        return PasswordResetValidation.confirmPasswordError(newPassword: newPassword, confirmPassword: confirmPassword)
    }

    var showFormErrorSummary: Bool {
        guard let formError else { return false }
        return formError != .missingOrInvalidFields
    }

    /// Validates both fields, then — only if valid — submits the new password (AC13–AC16).
    func submit() async {
        guard !isSubmitting else { return }
        didAttemptSubmit = true

        let newPasswordError = PasswordResetValidation.newPasswordError(newPassword)
        let confirmError = PasswordResetValidation.confirmPasswordError(newPassword: newPassword, confirmPassword: confirmPassword)
        formError = (newPasswordError == nil && confirmError == nil) ? nil : .missingOrInvalidFields
        guard newPasswordError == nil, confirmError == nil else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let submittedPassword = newPassword
        let outcome = await resetter.submitNewPassword(submittedPassword)
        // Both password fields are cleared after every attempt, success or failure (security.
        // instructions.md: never retain a credential longer than needed to submit it).
        newPassword = ""
        confirmPassword = ""

        switch outcome {
        case .completed:
            formError = nil
            router.push(.complete)
        case .doesNotMeetPolicy:
            formError = .doesNotMeetPolicy
        case .sessionExpired:
            formError = .sessionExpired
        case .network:
            formError = .network
        case .serviceUnavailable:
            formError = .serviceUnavailable
        }
    }

    func clearFormError() {
        formError = nil
    }
}
