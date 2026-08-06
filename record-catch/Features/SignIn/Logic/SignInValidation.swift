//
//  SignInValidation.swift
//  record-catch
//
//  Pure, static, presentation-agnostic validation for the Sign In screen.
//  UI only — presence checks only, no email format regex, no auth.
//

import Foundation

/// Per-field validation failures for the Sign In form.
enum SignInFieldError: Equatable {
    case emptyEmail
    case emptyPassword

    /// String Catalog key for the localised inline error message.
    var localizationKey: String {
        switch self {
        case .emptyEmail: return "signIn.error.email.empty"
        case .emptyPassword: return "signIn.error.password.empty"
        }
    }
}

/// Overall form-level state after a submit attempt.
enum SignInFormError: Equatable {
    case none
    case missingFields
    case invalidCredentials

    /// String Catalog key for the localised summary message, if any.
    var localizationKey: String? {
        switch self {
        case .none: return nil
        case .missingFields: return nil
        case .invalidCredentials: return "signIn.error.credentials"
        }
    }
}

/// Pure validation helpers. Stateless and trivially unit-testable.
enum SignInValidation {

    /// Returns `true` when the value is empty or whitespace-only.
    static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Validates the email field (presence only).
    static func emailError(_ email: String) -> SignInFieldError? {
        isBlank(email) ? .emptyEmail : nil
    }

    /// Validates the password field (presence only).
    static func passwordError(_ password: String) -> SignInFieldError? {
        isBlank(password) ? .emptyPassword : nil
    }

    /// Maps field-level results to an overall form state.
    ///
    /// If any field is missing, the form is in `.missingFields`. Otherwise the
    /// form is valid (`.none`) — credential errors are decided by the caller
    /// (stubbed in this UI-only phase).
    static func formError(email: String, password: String) -> SignInFormError {
        let hasMissing = emailError(email) != nil || passwordError(password) != nil
        return hasMissing ? .missingFields : .none
    }
}
