//
//  SignInValidation.swift
//  record-catch
//
//  Pure, static, presentation-agnostic validation for the Sign In screen. No I/O, no auth — see
//  ADR-0001's "pure helper" pattern and ADR-0022 (real authentication happens one layer up, in
//  `SignInViewModel` via `Authenticating`).
//

import Foundation

/// Per-field validation failures for the Sign In form.
enum SignInFieldError: Equatable {
    case emptyEmail
    case invalidEmailFormat
    case emptyPassword

    /// String Catalog key for the localised inline error message.
    var localizationKey: String {
        switch self {
        case .emptyEmail: return "signIn.error.email.empty"
        case .invalidEmailFormat: return "signIn.error.email.invalid"
        case .emptyPassword: return "signIn.error.password.empty"
        }
    }
}

/// Overall form-level state after a submit attempt.
enum SignInFormError: Equatable {
    case none
    case missingOrInvalidFields
    case invalidCredentials
    /// No network connectivity — sign-in was not attempted (ADR-0022 §3).
    case network
    /// Any other Entra/MSAL failure (including an unsupported step such as MFA or a browser
    /// requirement, and rate-limiting/lockout) — one provisional message pending content review
    /// (ADR-0022 §7).
    case serviceUnavailable
    /// `EntraConfiguration` placeholders are not yet populated for this stage (ADR-0022 §6).
    case notConfigured

    /// String Catalog key for the localised summary message, if any.
    var localizationKey: String? {
        switch self {
        case .none: return nil
        case .missingOrInvalidFields: return nil
        case .invalidCredentials: return "signIn.error.credentials"
        case .network: return "signIn.error.service"
        case .serviceUnavailable: return "signIn.error.service"
        case .notConfigured: return "signIn.error.service"
        }
    }
}

/// Pure validation helpers. Stateless and trivially unit-testable.
enum SignInValidation {

    /// Returns `true` when the value is empty or whitespace-only.
    static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Trims leading/trailing whitespace and lowercases, per the ticket's validation rules
    /// (email address is not case-sensitive; leading/trailing spaces are removed automatically).
    static func normalisedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Validates the email field: presence, then a practical format check. Presence is checked
    /// first so an empty field never also reports "invalid format".
    static func emailError(_ email: String) -> SignInFieldError? {
        if isBlank(email) { return .emptyEmail }
        return isValidEmailFormat(normalisedEmail(email)) ? nil : .invalidEmailFormat
    }

    /// A practical email format check: exactly one `@`, a non-empty local part, and a domain part
    /// containing at least one `.` with a non-empty label on each side — deliberately not a full
    /// RFC 5322 implementation, which is neither necessary nor sufficient for real validation
    /// (the authoritative check is Entra's own at sign-in time).
    static func isValidEmailFormat(_ email: String) -> Bool {
        guard !email.contains(where: \.isWhitespace) else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let localPart = parts[0]
        let domainPart = parts[1]
        guard !localPart.isEmpty, !domainPart.isEmpty else { return false }

        let domainLabels = domainPart.split(separator: ".", omittingEmptySubsequences: false)
        guard domainLabels.count >= 2 else { return false }
        return domainLabels.allSatisfy { !$0.isEmpty }
    }

    /// Validates the password field (presence only — never trimmed, since whitespace may be a
    /// deliberate part of the password).
    static func passwordError(_ password: String) -> SignInFieldError? {
        isBlank(password) ? .emptyPassword : nil
    }

    /// Maps field-level results to an overall form state.
    ///
    /// If any field is missing/invalid, the form is `.missingOrInvalidFields` and the caller must
    /// not attempt sign-in (ES1–ES4). Otherwise the form is valid (`.none`) and the caller may
    /// proceed to call `Authenticating`.
    static func formError(email: String, password: String) -> SignInFormError {
        let hasInvalid = emailError(email) != nil || passwordError(password) != nil
        return hasInvalid ? .missingOrInvalidFields : .none
    }
}
