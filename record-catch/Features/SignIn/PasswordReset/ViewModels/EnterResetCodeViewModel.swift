//
//  EnterResetCodeViewModel.swift
//  record-catch
//
//  View model for the "Enter your reset code" screen (AC5–AC10, ADR-0027).
//

import Foundation

enum ResetCodeFormError: Equatable {
    case missingCode
    case invalidCode
    case expiredCode
    case network
    case serviceUnavailable

    var localizationKey: String? {
        switch self {
        case .missingCode: return nil
        case .invalidCode: return "passwordReset.code.error.invalid"
        case .expiredCode: return "passwordReset.code.error.expired"
        case .network, .serviceUnavailable: return "passwordReset.error.service"
        }
    }
}

@MainActor
@Observable
final class EnterResetCodeViewModel {

    var code: String = ""
    private(set) var didAttemptSubmit = false
    private(set) var isSubmitting = false
    private(set) var formError: ResetCodeFormError?

    private let resetter: any PasswordResetting
    private let router: PasswordResetRouter

    init(resetter: any PasswordResetting, router: PasswordResetRouter) {
        self.resetter = resetter
        self.router = router
    }

    var codeFieldError: ResetCodeFieldError? {
        guard didAttemptSubmit, formError == nil || formError == .missingCode else { return nil }
        return PasswordResetValidation.codeError(code)
    }

    var showFormErrorSummary: Bool {
        guard let formError else { return false }
        return formError != .missingCode
    }

    /// Whether "Send a new code" should be offered distinctly (AC8 — always visible per the
    /// design, but surfaced here in case a future design gates it on the expired state).
    var showSendNewCode: Bool { true }

    /// Validates, then verifies the code with Entra (AC6/AC7/AC8/AC10).
    func submit() async {
        guard !isSubmitting else { return }
        didAttemptSubmit = true

        let fieldError = PasswordResetValidation.codeError(code)
        formError = fieldError == nil ? nil : .missingCode
        guard fieldError == nil else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let normalisedCode = PasswordResetValidation.normalisedCode(code)
        switch await resetter.verifyCode(normalisedCode) {
        case .verified:
            formError = nil
            router.push(.createPassword)
        case .invalidCode:
            formError = .invalidCode
        case .expired:
            formError = .expiredCode
        case .network:
            formError = .network
        case .serviceUnavailable:
            formError = .serviceUnavailable
        }
    }

    /// "Send a new code" (AC9): drops any in-flight reset state and returns to a fresh "Reset
    /// your password" screen with the email blank.
    func requestNewCode() {
        resetter.cancel()
        router.restart()
    }

    func clearFormError() {
        formError = nil
    }
}
