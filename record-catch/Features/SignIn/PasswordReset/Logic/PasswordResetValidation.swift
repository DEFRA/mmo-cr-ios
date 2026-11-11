//
//  PasswordResetValidation.swift
//  record-catch
//
//  Pure, static, presentation-agnostic validation for the password-reset journey (ADR-0027).
//  Mirrors `SignInValidation`'s "pure helper" pattern — no I/O, no auth.
//

import Foundation

/// Per-field validation failures for the "Reset your password" screen.
enum ResetEmailFieldError: Equatable {
    case emptyEmail
    case invalidEmailFormat

    var localizationKey: String {
        switch self {
        case .emptyEmail: return "passwordReset.email.error.empty"
        case .invalidEmailFormat: return "passwordReset.email.error.invalid"
        }
    }
}

/// Per-field validation failure for the "Enter your reset code" screen (AC6).
enum ResetCodeFieldError: Equatable {
    case emptyCode

    var localizationKey: String { "passwordReset.code.error.empty" }
}

/// Per-field validation failures for the "Create a new password" screen (AC13–AC15).
enum NewPasswordFieldError: Equatable {
    case emptyPassword
    case tooShort
    case tooLong
    case notEnoughCharacterClasses

    var localizationKey: String {
        switch self {
        case .emptyPassword: return "passwordReset.newPassword.error.empty"
        case .tooShort, .notEnoughCharacterClasses: return "passwordReset.newPassword.error.requirements"
        case .tooLong: return "passwordReset.newPassword.error.tooLong"
        }
    }
}

enum ConfirmPasswordFieldError: Equatable {
    case empty
    case mismatch

    var localizationKey: String {
        switch self {
        case .empty: return "passwordReset.confirmPassword.error.empty"
        case .mismatch: return "passwordReset.confirmPassword.error.mismatch"
        }
    }
}

enum PasswordResetValidation {

    // MARK: - Email (AC2)

    static func emailError(_ email: String) -> ResetEmailFieldError? {
        if SignInValidation.isBlank(email) { return .emptyEmail }
        return SignInValidation.isValidEmailFormat(SignInValidation.normalisedEmail(email)) ? nil : .invalidEmailFormat
    }

    static func normalisedEmail(_ email: String) -> String {
        SignInValidation.normalisedEmail(email)
    }

    // MARK: - Reset code (AC6)

    static func codeError(_ code: String) -> ResetCodeFieldError? {
        SignInValidation.isBlank(code) ? .emptyCode : nil
    }

    /// The code is never trimmed/lowercased beyond surrounding whitespace — it is submitted
    /// verbatim to Entra, which performs the authoritative check.
    static func normalisedCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - New password (AC13–AC15)

    /// Checks presence, then length, then the "3 of 4 character classes" rule (ADR-0027 §6) —
    /// deliberately never trims the password, since whitespace may be a deliberate character.
    static func newPasswordError(_ password: String) -> NewPasswordFieldError? {
        if password.isEmpty { return .emptyPassword }
        if password.count < PasswordResetConfiguration.minimumPasswordLength { return .tooShort }
        if password.count > PasswordResetConfiguration.maximumPasswordLength { return .tooLong }
        if characterClassCount(password) < PasswordResetConfiguration.minimumCharacterClasses {
            return .notEnoughCharacterClasses
        }
        return nil
    }

    /// Counts how many of the four character classes (uppercase, lowercase, digit, symbol) appear
    /// at least once in `password`.
    static func characterClassCount(_ password: String) -> Int {
        var hasUpper = false, hasLower = false, hasDigit = false, hasSymbol = false
        for character in password {
            if character.isUppercase { hasUpper = true }
            else if character.isLowercase { hasLower = true }
            else if character.isNumber { hasDigit = true }
            else if !character.isWhitespace { hasSymbol = true }
        }
        return [hasUpper, hasLower, hasDigit, hasSymbol].filter { $0 }.count
    }

    // MARK: - Confirm new password (AC14/AC15)

    static func confirmPasswordError(newPassword: String, confirmPassword: String) -> ConfirmPasswordFieldError? {
        if confirmPassword.isEmpty { return .empty }
        return confirmPassword == newPassword ? nil : .mismatch
    }
}
